package api

import (
	"encoding/json"
	"log"
	"net/http"

	"xjtu-course-genius/internal/auth"
	"xjtu-course-genius/internal/config"
	"xjtu-course-genius/internal/course"
	"xjtu-course-genius/internal/session"

	"github.com/go-chi/chi/v5"
	"github.com/go-resty/resty/v2"
)

type Server struct {
	client *resty.Client
	engine *course.Engine
}

func NewServer() *Server {
	client := session.NewClient()
	return &Server{
		client: client,
		engine: course.NewEngine(client),
	}
}

// ── Login & MFA ──

func (s *Server) HandleLogin(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Account  string `json:"account"`
		Password string `json:"password"`
		Captcha  string `json:"captcha"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, 400, map[string]string{"error": "参数错误"})
		return
	}
	if req.Account == "" || req.Password == "" {
		writeJSON(w, 400, map[string]string{"error": "账号密码不能为空"})
		return
	}

	st := session.Get()
	st.Account = req.Account
	st.Password = req.Password

	// Captcha retry: reuse the saved client (same CAS session/execution as captcha image)
	var client *resty.Client
	log.Printf("[captcha] HandleLogin: captcha=%q (len=%d) hasSavedClient=%v", req.Captcha, len(req.Captcha), s.client != nil)
	if req.Captcha != "" && s.client != nil {
		client = s.client
	} else {
		client = session.NewClient()
	}

	_, err := client.R().Head("https://xkfw.xjtu.edu.cn")
	if err != nil {
		writeJSON(w, 500, map[string]string{"error": "网络连接失败，请检查网络"})
		return
	}

	err = auth.FullLoginWithCaptcha(client, req.Account, req.Password, req.Captcha)
	if err != nil {
		// Save client cookies so MFA/account-choice/captcha flows can continue
		session.SaveCookiesFromHTTP(client.GetClient())
		s.client = client
		s.engine.SetClient(client)
		if capErr, ok := err.(*auth.CaptchaNeededError); ok {
			resp := map[string]interface{}{
				"captcha_required": true,
			}
			if capErr.Message != "" {
				resp["error"] = capErr.Message
			}
			writeJSON(w, 200, resp)
			return
		}
		if acErr, ok := err.(*auth.AccountChoiceNeededError); ok {
			writeJSON(w, 200, map[string]interface{}{
				"account_choice_required": true,
				"choices":                 acErr.Choices,
			})
			return
		}
		if mfaErr, ok := err.(*auth.MFANeededError); ok {
			auth.SetPendingMFAState(mfaErr.State)
			writeJSON(w, 200, map[string]interface{}{
				"mfa_required":   true,
				"state":           mfaErr.State,
				"isSafetyVerify":  mfaErr.IsSafetyVerify,
			})
			return
		}
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}

	// Set Token header on client after successful login
	token := session.Get().Token
	if token != "" {
		client.SetHeader("Token", token)
	}
	session.SaveCookiesFromHTTP(client.GetClient())
	s.client = client
		s.engine.SetClient(client)

	writeJSON(w, 200, map[string]interface{}{
		"success":     true,
		"studentCode": session.Get().StudentCode,
		"campus":      session.Get().Campus,
	})
}

func (s *Server) HandleMFAInit(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Method string `json:"method"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	result, err := auth.InitMFA(s.client, req.Method)
	if err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, 200, result)
}

func (s *Server) HandleMFASend(w http.ResponseWriter, r *http.Request) {
	if err := auth.SendMFACode(s.client); err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, 200, map[string]string{"status": "ok"})
}

func (s *Server) HandleMFAVerify(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Code string `json:"code"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	if err := auth.VerifyMFACode(s.client, req.Code); err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}

	client := session.NewClient()

	// Safety Verify flow: submit safety verify form after MFA
	if auth.IsSafetyVerifyFlow() {
		if err := auth.FinishSafetyVerifyLogin(client); err != nil {
			writeJSON(w, 500, map[string]string{"error": "二次认证失败: " + err.Error()})
			return
		}
		auth.ClearMFA()
		session.SaveCookies(client)
		client.SetHeader("Token", session.Get().Token)
		s.client = client
		s.engine.SetClient(client)
		writeJSON(w, 200, map[string]interface{}{
			"success":     true,
			"studentCode": session.Get().StudentCode,
			"campus":      session.Get().Campus,
		})
		return
	}

	// Regular MFA: follow redirects to register
	if err := auth.CompleteMFALogin(client); err != nil {
		writeJSON(w, 500, map[string]string{"error": "MFA验证通过但登录失败: " + err.Error()})
		return
	}

	auth.ClearMFA()
	session.SaveCookies(client)
		client.SetHeader("Token", session.Get().Token)
	s.client = client
		s.engine.SetClient(client)

	writeJSON(w, 200, map[string]interface{}{
		"success":     true,
		"studentCode": session.Get().StudentCode,
			"campus":      session.Get().Campus,
	})
}

func (s *Server) HandleCaptchaImage(w http.ResponseWriter, r *http.Request) {
	img, err := auth.GetCaptchaImage(s.client)
	if err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	w.Header().Set("Content-Type", "image/jpeg")
	w.Write(img)
}

func (s *Server) HandleChooseAccount(w http.ResponseWriter, r *http.Request) {
	var req struct {
		AccountType string `json:"accountType"` // "undergraduate" or "postgraduate"
	}
	json.NewDecoder(r.Body).Decode(&req)

	client := session.NewClient()
	if err := auth.ChooseAccount(client, req.AccountType); err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	session.SaveCookies(client)
		client.SetHeader("Token", session.Get().Token)
	s.client = client
		s.engine.SetClient(client)
	writeJSON(w, 200, map[string]interface{}{
		"success":     true,
		"studentCode": session.Get().StudentCode,
			"campus":      session.Get().Campus,
	})
}

// ── Batch / Rounds ──

func (s *Server) HandleBatches(w http.ResponseWriter, r *http.Request) {
	batches, err := course.GetBatches(s.client)
	if err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, 200, batches)
}

func (s *Server) HandleEnterRound(w http.ResponseWriter, r *http.Request) {
	var req struct {
		BatchCode string `json:"batchCode"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	if err := course.EnterRound(s.client, req.BatchCode); err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, 200, map[string]interface{}{
		"success": true,
		"campus":  session.Get().Campus,
	})
}

// ── Courses ──

func (s *Server) HandleSelectedCourses(w http.ResponseWriter, r *http.Request) {
	results, err := course.QuerySelected(s.client)
	if err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, 200, results)
}

func (s *Server) HandleDropCourse(w http.ResponseWriter, r *http.Request) {
	var req struct {
		TeachingClassID string `json:"teachingClassId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, 400, map[string]string{"error": "参数错误"})
		return
	}
	log.Printf("[api] 退课 %s", req.TeachingClassID)
	if err := course.DeleteVolunteer(s.client, req.TeachingClassID); err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, 200, map[string]string{"status": "ok"})
}

func (s *Server) HandleQueryCourses(w http.ResponseWriter, r *http.Request) {
	classType := chi.URLParam(r, "type")
	keyword := r.URL.Query().Get("keyword")

	courses, total, err := course.QueryCourses(s.client, classType, keyword)
	if err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, 200, map[string]interface{}{
		"total":   total,
		"courses": courses,
	})
}

// ── Selection Engine ──

func (s *Server) HandleSelectionStart(w http.ResponseWriter, r *http.Request) {
	s.engine.Start()
	writeJSON(w, 200, map[string]string{"status": "started"})
}

func (s *Server) HandleSelectionStop(w http.ResponseWriter, r *http.Request) {
	s.engine.Stop()
	writeJSON(w, 200, map[string]string{"status": "stopped"})
}

func (s *Server) HandleSelectionStatus(w http.ResponseWriter, r *http.Request) {
	status := s.engine.Status()
	writeJSON(w, 200, status)
}

// ── Config ──

func (s *Server) HandleConfigGet(w http.ResponseWriter, r *http.Request) {
	cfg := config.Get()
	writeJSON(w, 200, cfg)
}

func (s *Server) HandleConfigSave(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Course     [][]string `json:"course"`
		DelCourses [][]string `json:"delcourses"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, 400, map[string]string{"error": "参数错误"})
		return
	}
	config.SetCourse(req.Course, req.DelCourses)
	config.Save()
	s.engine.SetCourses(req.Course, req.DelCourses)

	writeJSON(w, 200, map[string]string{"status": "ok"})
}

// ── Campus ──

func (s *Server) HandleCampusSet(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Campus string `json:"campus"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	session.SetCampus(req.Campus)
	writeJSON(w, 200, map[string]string{"status": "ok"})
}

func (s *Server) HandleCampusList(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, 200, session.Get().CampusList)
}

// ── Session alive check ──

func (s *Server) HandleSessionCheck(w http.ResponseWriter, r *http.Request) {
	alive := auth.IsSessionAlive(s.client)
	writeJSON(w, 200, map[string]bool{"alive": alive})
}

func (s *Server) HandleRelogin(w http.ResponseWriter, r *http.Request) {
	client := session.NewClient()
	if err := auth.ReloginIfNeeded(client); err != nil {
		writeJSON(w, 500, map[string]string{"error": err.Error()})
		return
	}
	session.SaveCookies(client)
		client.SetHeader("Token", session.Get().Token)
	s.client = client
		s.engine.SetClient(client)
	writeJSON(w, 200, map[string]string{"status": "ok"})
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func init() {
	log.SetFlags(log.Ltime)
}
