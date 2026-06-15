package course

import (
	"encoding/json"
	"fmt"
	stdlog "log"
	"math"
	"strings"
	"sync"
	"time"

	"xjtu-course-genius/internal/session"

	"github.com/go-resty/resty/v2"
)

const baseURL = "https://xkfw.xjtu.edu.cn"

// ── Course cache (per type+campus+batch, invalidated on change) ──
var courseCache = struct {
	mu   sync.RWMutex
	data map[string][]CourseInfo
}{data: make(map[string][]CourseInfo)}

func cacheKey(classType, campus string) string {
	return fmt.Sprintf("%s:%s", classType, campus)
}

func getCached(classType, campus string) ([]CourseInfo, bool) {
	courseCache.mu.RLock()
	defer courseCache.mu.RUnlock()
	courses, ok := courseCache.data[cacheKey(classType, campus)]
	return courses, ok
}

func setCache(classType, campus string, courses []CourseInfo) {
	courseCache.mu.Lock()
	defer courseCache.mu.Unlock()
	courseCache.data[cacheKey(classType, campus)] = courses
}

func WarmupCache(client *resty.Client) {
	s := session.Get()
	types := []string{"TJKC", "FANKC", "FAWKC", "XGXK", "TYKC"}

	// Warm up ALL campuses, not just current one
	for _, campus := range s.CampusList {
		for _, t := range types {
			if _, ok := getCached(t, campus.Code); ok {
				continue
			}
			cfg, ok := queryConfigs[t]
			if !ok { continue }
			isXGXK := t == "XGXK"
			stdlog.Printf("[cache] warming up %s campus=%s", t, campus.Code)
			courses, _, err := fetchAllPagesForCampus(client, cfg.URL, t, "", cfg.HasTCLists, isXGXK, campus.Code)
			if err == nil {
				setCache(t, campus.Code, courses)
			}
		}
	}
}

func ClearCourseCache() {
	courseCache.mu.Lock()
	defer courseCache.mu.Unlock()
	courseCache.data = make(map[string][]CourseInfo)
}

func timestamp() int64 { return time.Now().UnixMilli() }

// ── Selected courses ──

func QuerySelected(client *resty.Client) ([]CourseResult, error) {
	s := session.Get()
	url := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/elective/courseResult.do", baseURL)
	resp, err := client.R().
		SetQueryParams(map[string]string{
			"timestamp":         fmt.Sprintf("%d", timestamp()),
			"studentCode":       s.StudentCode,
			"electiveBatchCode": s.BatchCode,
		}).
		Get(url)
	if err != nil {
		return nil, err
	}
	var j struct {
		DataList []struct {
			TeachingClassID string `json:"teachingClassID"`
			CourseName      string `json:"courseName"`
			TeacherName     string `json:"teacherName"`
			TeachingPlace   string `json:"teachingPlace"`
			CourseType      string `json:"courseType"`
			CourseTypeName  string `json:"courseTypeName"`
			Campus          string `json:"campus"`
			CampusName      string `json:"campusName"`
			Credit          string `json:"credit"`
		} `json:"dataList"`
	}
	if err := json.Unmarshal(resp.Body(), &j); err != nil {
		return nil, err
	}
	var results []CourseResult
	for _, d := range j.DataList {
		results = append(results, CourseResult{
			TeachingClassID: d.TeachingClassID,
			CourseName:      d.CourseName,
			TeacherName:     d.TeacherName,
			TeachingPlace:   d.TeachingPlace,
			ClassType:       d.CourseType,
				CourseTypeName:  d.CourseTypeName,
			Campus:          d.Campus,
			CampusName:      d.CampusName,
			Credit:          d.Credit,
			Selected:        true,
		})
	}
	return results, nil
}

// ── Course queries by type ──

type queryConfig struct {
	URL        string
	HasTCLists bool
}

var queryConfigs = map[string]queryConfig{
	"TJKC":  {"recommendedCourse.do", true},
	"FANKC": {"programCourse.do", true},
	"FAWKC": {"programCourse.do", true},
	"TYKC":  {"programCourse.do", true},
	"XGXK":  {"publicCourse.do", false},
}

func QueryCourses(client *resty.Client, classType, keyword string) ([]CourseInfo, int, error) {
	classType = strings.ToUpper(classType)
	if classType == "ALL" {
		return queryAllTypes(client, keyword)
	}

	campus := session.Get().Campus

	// Use cache when no keyword, filter cache when keyword provided
	if keyword == "" {
		if cached, ok := getCached(classType, campus); ok {
			return cached, len(cached), nil
		}
	} else {
		if cached, ok := getCached(classType, campus); ok {
			kw := strings.ToLower(keyword)
			var filtered []CourseInfo
			for _, c := range cached {
				if strings.Contains(strings.ToLower(c.CourseName), kw) ||
					strings.Contains(strings.ToLower(c.TeacherName), kw) {
					filtered = append(filtered, c)
				}
			}
			return filtered, len(filtered), nil
		}
	}

	cfg, ok := queryConfigs[classType]
	if !ok {
		return nil, 0, fmt.Errorf("未知的课程类型: %s", classType)
	}
	isXGXK := classType == "XGXK"
	courses, total, err := fetchAllPages(client, cfg.URL, classType, "", cfg.HasTCLists, isXGXK)
	if err != nil {
		return nil, 0, err
	}

	// Cache full list (no keyword)
	setCache(classType, campus, courses)

	if keyword != "" {
		kw := strings.ToLower(keyword)
		var filtered []CourseInfo
		for _, c := range courses {
			if strings.Contains(strings.ToLower(c.CourseName), kw) ||
				strings.Contains(strings.ToLower(c.TeacherName), kw) {
				filtered = append(filtered, c)
			}
		}
		return filtered, len(filtered), nil
	}
	return courses, total, nil
}

func queryAllTypes(client *resty.Client, keyword string) ([]CourseInfo, int, error) {
	var all []CourseInfo
	types := []string{"TJKC", "FANKC", "FAWKC", "XGXK", "TYKC"}

	// First ensure current campus is cached (fetch all types)
	campus := session.Get().Campus
	for _, t := range types {
		if _, ok := getCached(t, campus); !ok {
			cfg, okCfg := queryConfigs[t]
			if !okCfg { continue }
			isXGXK := t == "XGXK"
			courses, _, err := fetchAllPagesForCampus(client, cfg.URL, t, "", cfg.HasTCLists, isXGXK, campus)
			if err == nil {
				setCache(t, campus, courses)
			}
		}
	}

	// Search across ALL cached types+campuses
	kw := strings.ToLower(keyword)
	courseCache.mu.RLock()
	for _, courses := range courseCache.data {
		for _, c := range courses {
			if keyword == "" ||
				strings.Contains(strings.ToLower(c.CourseName), kw) ||
				strings.Contains(strings.ToLower(c.TeacherName), kw) {
				all = append(all, c)
			}
		}
	}
	courseCache.mu.RUnlock()

	return all, len(all), nil
}

func fetchAllPages(client *resty.Client, endpoint, classType, keyword string, hasTCLists, isXGXK bool) ([]CourseInfo, int, error) {
	return fetchAllPagesForCampus(client, endpoint, classType, keyword, hasTCLists, isXGXK, session.Get().Campus)
}

func fetchAllPagesForCampus(client *resty.Client, endpoint, classType, keyword string, hasTCLists, isXGXK bool, campus string) ([]CourseInfo, int, error) {
	s := session.Get()
	var all []CourseInfo

	querySetting := map[string]interface{}{
		"data": map[string]string{
			"studentCode":       s.StudentCode,
			"campus":            campus,
			"electiveBatchCode": s.BatchCode,
			"isMajor":           "1",
			"teachingClassType": classType,
			"checkConflict":     "2",
			"checkCapacity":     "2",
			"queryContent":      keyword,
		},
		"pageSize":   "50",
		"pageNumber": "0",
		"order":      "",
	}

	qsBytes, _ := json.Marshal(querySetting)
	url := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/elective/%s", baseURL, endpoint)

	resp, err := client.R().
		SetFormData(map[string]string{"querySetting": string(qsBytes)}).
		Post(url)
	if err != nil {
		return nil, 0, err
	}

	var j struct {
		TotalCount interface{}     `json:"totalCount"`
		DataList   json.RawMessage `json:"dataList"`
	}
	json.Unmarshal(resp.Body(), &j)

	parsed := parseDataList(j.DataList, classType, hasTCLists, isXGXK)
	all = append(all, parsed...)

	totalCount := 0
	switch v := j.TotalCount.(type) {
	case float64:
		totalCount = int(v)
	}

	totalPages := int(math.Ceil(float64(totalCount) / 50.0))
	for page := 1; page < totalPages; page++ {
		querySetting["pageNumber"] = fmt.Sprintf("%d", page)
		qsBytes, _ := json.Marshal(querySetting)
		resp, err := client.R().
			SetFormData(map[string]string{"querySetting": string(qsBytes)}).
			Post(url)
		if err != nil {
			break
		}
		var pj struct {
			DataList json.RawMessage `json:"dataList"`
		}
		json.Unmarshal(resp.Body(), &pj)
		all = append(all, parseDataList(pj.DataList, classType, hasTCLists, isXGXK)...)
	}

	return all, len(all), nil
}

func parseDataList(raw json.RawMessage, classType string, hasTCLists, isXGXK bool) []CourseInfo {
	var results []CourseInfo
	if isXGXK {
		var list []struct {
			CourseName       string `json:"courseName"`
			Campus           string `json:"campus"`
			TeachingTimeList []struct {
				TeachingClassID string `json:"teachingClassID"`
				TeacherName     string `json:"teacherName"`
				TeachingPlace   string `json:"teachingPlace"`
				CourseName      string `json:"courseName"`
			} `json:"teachingTimeList"`
		}
		json.Unmarshal(raw, &list)
		for _, item := range list {
			for _, tc := range item.TeachingTimeList {
				name := item.CourseName
				if name == "" {
					name = tc.CourseName
				}
				results = append(results, CourseInfo{
					TeachingClassID: tc.TeachingClassID,
					CourseName:      name,
					TeacherName:     tc.TeacherName,
					TeachingPlace:   tc.TeachingPlace,
					ClassType:       classType,
					CourseTypeName:  classType,
					Campus:          item.Campus,
				})
			}
		}
	} else if hasTCLists {
		var list []struct {
			CourseName string `json:"courseName"`
			TcList     []struct {
				TeachingClassID string `json:"teachingClassID"`
				TeacherName     string `json:"teacherName"`
				TeachingPlace   string `json:"teachingPlace"`
				SportName       string `json:"sportName"`
				Campus          string `json:"campus"`
			} `json:"tcList"`
		}
		json.Unmarshal(raw, &list)
		for _, a := range list {
			for _, tc := range a.TcList {
				name := a.CourseName
				if classType == "TYKC" && tc.SportName != "" {
					name = name + "-" + tc.SportName
				}
				results = append(results, CourseInfo{
					TeachingClassID: tc.TeachingClassID,
					CourseName:      name,
					TeacherName:     tc.TeacherName,
					TeachingPlace:   tc.TeachingPlace,
					ClassType:       classType,
					CourseTypeName:  classType,
					Campus:          tc.Campus,
				})
			}
		}
	}
	return results
}

// ── Capacity check ──

func CheckCapacity(client *resty.Client, teachingClassID string) (bool, error) {
	s := session.Get()
	url := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/elective/teachingclass/capacity.do", baseURL)
	resp, err := client.R().
		SetQueryParams(map[string]string{
			"teachingClassId": teachingClassID,
			"capacitySuffix":  "",
			"xh":              s.StudentCode,
			"timestamp":       fmt.Sprintf("%d", timestamp()),
		}).
		Get(url)
	if err != nil {
		stdlog.Printf("[sel] CheckCapacity %s: HTTP err=%v", teachingClassID, err)
		return false, err
	}
	stdlog.Printf("[sel] CheckCapacity %s: status=%d url=%s token=%s", teachingClassID, resp.StatusCode(), resp.Request.URL, s.Token[:20])
	var j struct {
		Data struct {
			NumberOfSelected string `json:"numberOfSelected"`
			ClassCapacity    string `json:"classCapacity"`
		} `json:"data"`
	}
	if err := json.Unmarshal(resp.Body(), &j); err != nil {
		stdlog.Printf("[sel] CheckCapacity %s: parse err=%v body=%s", teachingClassID, err, safeSlice(string(resp.Body()), 200))
		return false, err
	}
	selected := parseInt(j.Data.NumberOfSelected)
	capacity := parseInt(j.Data.ClassCapacity)
	hasRoom := selected < capacity
	stdlog.Printf("[sel] CheckCapacity %s: %d/%d hasRoom=%v", teachingClassID, selected, capacity, hasRoom)
	return hasRoom, nil
}

// ── Volunteer slots ──

var volunteerSlotsCache []map[string]string

func GetVolunteerSlots(client *resty.Client) []map[string]string {
	if volunteerSlotsCache != nil {
		return volunteerSlotsCache
	}
	url := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/publicinfo/volunteer.do", baseURL)
	resp, err := client.R().SetHeader("Token", session.Get().Token).Get(url)
	if err != nil {
		return []map[string]string{}
	}
	var j struct {
		DataList []struct {
			Grade json.Number `json:"grade"`
			Name  string      `json:"name"`
		} `json:"dataList"`
	}
	stdlog.Printf("[vol] GetVolunteerSlots body=%s", safeSlice(string(resp.Body()), 300))
	if json.Unmarshal(resp.Body(), &j) == nil && len(j.DataList) > 0 {
		for _, v := range j.DataList {
			volunteerSlotsCache = append(volunteerSlotsCache, map[string]string{
				"grade": v.Grade.String(), "name": v.Name,
			})
		}
		return volunteerSlotsCache
	}
	return []map[string]string{}
}

// Query valid volunteer slots for a specific course (原网页: queryCourseCanSelectVolunteer)
func QueryCourseVolunteerSlots(client *resty.Client, teachingClassID, classType, campus string) ([]string, error) {
	s := session.Get()
	if campus == "" {
		campus = "1"
	}
	data := map[string]string{
		"studentCode":       s.StudentCode,
		"electiveBatchCode": s.BatchCode,
		"teachingClassId":   teachingClassID,
		"teachingClassType": classType,
		"campus":            campus,
	}
	xkBytes, _ := json.Marshal(map[string]interface{}{"data": data})
	url := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/elective/course/volunteer.do?timestamp=%d",
		baseURL, time.Now().UnixMilli())
	resp, err := client.R().
		SetHeader("Token", s.Token).
		SetFormData(map[string]string{"queryParam": string(xkBytes)}).
		Post(url)
	if err != nil {
		return nil, err
	}
	stdlog.Printf("[vol] QueryCourseVolunteerSlots %s: body=%s", teachingClassID, safeSlice(string(resp.Body()), 300))
	var j struct {
		Data struct {
			ChooseVolunteerList []struct {
				Grade string `json:"grade"`
				Name  string `json:"name"`
			} `json:"chooseVolunteerList"`
		} `json:"data"`
	}
	if json.Unmarshal(resp.Body(), &j) == nil {
		var slots []string
		for _, v := range j.Data.ChooseVolunteerList {
			slots = append(slots, v.Grade)
		}
		return slots, nil
	}
	return nil, nil
}

// ── Volunteer / Delete ──

func Volunteer(client *resty.Client, teachingClassID, classType, campus, volunteerIndex string) error {
	s := session.Get()
	if campus == "" {
		campus = "1"
	}
	data := map[string]string{
		"operationType":     "1",
		"studentCode":       s.StudentCode,
		"electiveBatchCode": s.BatchCode,
		"teachingClassId":   teachingClassID,
		"isMajor":           "1",
		"campus":            campus,
		"teachingClassType": classType,
	}
	// 正选(typeCode=02) no volunteer needed; 预选 needs chooseVolunteer
	if st := session.Get(); st.BatchType != "02" && volunteerIndex != "" {
		data["chooseVolunteer"] = volunteerIndex
	}
	xk := map[string]interface{}{
		"data": data,
	}
	xkBytes, _ := json.Marshal(xk)
	url := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/elective/volunteer.do", baseURL)
	resp, err := client.R().
		SetFormData(map[string]string{"addParam": string(xkBytes)}).
		Post(url)
	if err != nil {
		stdlog.Printf("[sel] Volunteer %s: HTTP err=%v", teachingClassID, err)
		return err
	}
	stdlog.Printf("[sel] Volunteer %s: status=%d body=%s campus=%s", teachingClassID, resp.StatusCode(), safeSlice(string(resp.Body()), 200), campus)
	var vj struct {
		Code interface{} `json:"code"`
		Msg  string      `json:"msg"`
	}
	if json.Unmarshal(resp.Body(), &vj) == nil {
		ok := false
		switch c := vj.Code.(type) {
		case float64:
			ok = c == 0 || c == 1
		case string:
			ok = c == "0" || c == "1"
		}
		if ok {
			return nil
		}
		if vj.Msg != "" {
			return fmt.Errorf("选课失败: %s", vj.Msg)
		}
		return fmt.Errorf("选课失败: unknown error")
	}
	return nil
}

func DeleteVolunteer(client *resty.Client, teachingClassID string) error {
	s := session.Get()
	txkc := map[string]interface{}{
		"data": map[string]string{
			"operationType":     "2",
			"studentCode":       s.StudentCode,
			"electiveBatchCode": s.BatchCode,
			"teachingClassId":   teachingClassID,
			"isMajor":           "1",
		},
	}
	txkcBytes, _ := json.Marshal(txkc)
	url := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/elective/deleteVolunteer.do", baseURL)
	resp, err := client.R().
		SetQueryParams(map[string]string{
			"timestamp":   fmt.Sprintf("%d", timestamp()),
			"deleteParam": string(txkcBytes),
		}).
		Get(url)
	if err != nil {
		stdlog.Printf("[sel] DeleteVolunteer %s: HTTP err=%v", teachingClassID, err)
		return err
	}
	stdlog.Printf("[sel] DeleteVolunteer %s: status=%d body=%s", teachingClassID, resp.StatusCode(), safeSlice(string(resp.Body()), 200))
	return nil
}

func safeSlice(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max]
}

func parseInt(s string) int {
	var n int
	fmt.Sscanf(s, "%d", &n)
	return n
}
