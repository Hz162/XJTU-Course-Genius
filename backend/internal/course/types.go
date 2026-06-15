package course

type CourseInfo struct {
	TeachingClassID string `json:"teachingClassId"`
	CourseName      string `json:"courseName"`
	TeacherName     string `json:"teacherName"`
	TeachingPlace   string `json:"teachingPlace"`
	ClassTime       string `json:"classTime,omitempty"`
	ClassType       string `json:"classType"`
	CourseTypeName  string `json:"courseTypeName,omitempty"`
	CourseTypeCode  string `json:"courseTypeCode,omitempty"`
	Campus          string `json:"campus"`
}

type CourseResult struct {
	TeachingClassID string `json:"teachingClassId"`
	CourseName      string `json:"courseName"`
	TeacherName     string `json:"teacherName"`
	TeachingPlace   string `json:"teachingPlace"`
	ClassType       string `json:"classType"`
	CourseTypeName  string `json:"courseTypeName"`
	Campus          string `json:"campus"`
	CampusName      string `json:"campusName"`
	Credit          string `json:"credit"`
	Selected        bool   `json:"selected"`
}

type BatchInfo struct {
	Code      string `json:"code"`
	Name      string `json:"name"`
	CanSelect string `json:"canSelect"`
}

type SelectionStatus struct {
	Running     bool           `json:"running"`
	TotalCourse int            `json:"totalCourse"`
	Flags       []int          `json:"flags"` // 0=未抢到, 1=已抢到
	Progress    int            `json:"progress"`
	Log         []string       `json:"log"`
}
