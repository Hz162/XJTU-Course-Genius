package auth

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"xjtu-course-genius/internal/session"

	"github.com/go-resty/resty/v2"
)

const (
	baseURL    = "https://xkfw.xjtu.edu.cn"
	casBaseURL = "https://login.xjtu.edu.cn"
)

var failCount int

func ResetFailCount()          { failCount = 0 }
func IsCaptchaRequired() bool  { return failCount >= 3 }

// isCaptchaPage checks if CAS returned the login page with captcha required.
// CAS shows captcha when failN reaches the server threshold (typically 3).
func isCaptchaPage(body []byte) bool {
	s := string(body)
	// Must be the CAS login page (not a redirect or other page)
	if !strings.Contains(s, "fm1") || !strings.Contains(s, "execution") {
		return false
	}
	// Check for captcha indicators in the page
	return strings.Contains(s, "captcha.jpg") ||
		strings.Contains(s, "id=\"captcha\"") ||
		strings.Contains(s, "输入验证码")
}

// ── session alive check ──

func IsSessionAlive(client *resty.Client) bool {
	url := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/publicinfo/dictionary.do?timestamp=%d",
		baseURL, time.Now().UnixMilli())
	resp, err := client.R().SetHeader("Token", session.Get().Token).Get(url)
	if err != nil {
		return false
	}
	if strings.Contains(resp.Request.URL, "login.xjtu.edu.cn") || strings.Contains(resp.Request.URL, "cas") {
		return false
	}
	if resp.StatusCode() == http.StatusOK {
		var j struct{ Code interface{} }
		if json.Unmarshal(resp.Body(), &j) == nil {
			return true
		}
	}
	return false
}

// ── tiered re-login ──

func ReloginIfNeeded(client *resty.Client) error {
	if IsSessionAlive(client) {
		return nil
	}

	s := session.Get()
	stCode := s.StudentCode
	if stCode == "" {
		stCode = "null"
	}
	regURL := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/student/register.do?number=%s", baseURL, stCode)
	resp, err := client.R().Get(regURL)
	if err == nil && resp.StatusCode() == http.StatusOK {
		var j struct {
			Code interface{} `json:"code"`
			Data struct {
				Token  string `json:"token"`
				Number string `json:"number"`
			} `json:"data"`
		}
		if json.Unmarshal(resp.Body(), &j) == nil {
			if codeIsOK(j.Code) {
				if j.Data.Token != "" {
					session.SetToken(j.Data.Token)
					client.SetHeader("Token", j.Data.Token)
					if j.Data.Number != "" {
						session.SetStudentCode(j.Data.Number)
					}
					ResetFailCount()
						session.SaveCookies(client)
					return nil
				}
			}
		}
	}

	if err := FullLogin(client, s.Account, s.Password); err != nil {
		return err
	}
	if session.Get().Token != "" {
		client.SetHeader("Token", session.Get().Token)
	}
	ResetFailCount()
	session.SaveCookies(client)
	return nil
}

// ── full CAS login (state-machine based) ──

// stored state for safety verify continuation
var safetyVerifyURL string
var safetyVerifyExecution string
var safetyVerifySecState string

// stored state for account choice
var accountChoiceExecution string
var accountChoices []map[string]string

func FullLogin(client *resty.Client, account, password string) error {
	return FullLoginWithCaptcha(client, account, password, "")
}

func FullLoginWithCaptcha(client *resty.Client, account, password, captcha string) error {
	// Match XJTUToolBox: client-side fail count simulates CAS server threshold
	if IsCaptchaRequired() && captcha == "" {
		return &CaptchaNeededError{}
	}

	fpID, err := GetFingerprint()
	if err != nil {
		return fmt.Errorf("指纹获取失败: %w", err)
	}
	session.SetFpVisitorID(fpID)

	// Use raw http.Client for CAS login (resty's cookie jar has issues)
	httpClient := client.GetClient()

	// Step 1: GET xkfw → CAS redirect (don't follow, we need the CAS URL)
	resp, err := httpClient.Get(baseURL)
	if err != nil {
		return fmt.Errorf("访问选课系统失败: %w", err)
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	casURL := resp.Request.URL.String()
	execution := extractExecution(body)

	// Step 2: GET public key
	pubResp, err := httpClient.Get(casBaseURL + "/cas/jwt/publicKey")
	if err != nil {
		return fmt.Errorf("获取公钥失败: %w", err)
	}
	pubBody, _ := io.ReadAll(pubResp.Body)
	pubResp.Body.Close()
	SetPubKey(string(pubBody))

	encPwd, err := EncryptPassword(password)
	if err != nil {
		return fmt.Errorf("密码加密失败: %w", err)
	}

	// Step 3: MFA detect (use resty for this — it's a simple JSON API)
	mfaNeed, mfaState, err := detectMFA(client, account, encPwd, fpID)
	if err != nil {
		return fmt.Errorf("MFA检测失败: %w", err)
	}

	if mfaNeed {
		currentMFA = &MFAInfo{State: mfaState, Flow: MFAFlowMFA}
		ClearSafetyVerify()
		return &MFANeededError{State: mfaState, Reason: "需要MFA验证", IsMFA: true}
	}

	// Step 4: submit CAS form using raw http client (so cookies are properly stored)
	return postCASRaw(httpClient, casURL, account, encPwd, execution, mfaState, fpID, captcha, "")
}

func postCASAndProcess(client *resty.Client, casURL, account, encPwd, execution, mfaState, fpID, captcha, trustAgent string) error {
	data := map[string]string{
		"username":    account,
		"password":    encPwd,
		"captcha":     captcha,
		"currentMenu": "1",
		"failN":       fmt.Sprintf("%d", failCount),
		"mfaState":    mfaState,
		"execution":   execution,
		"_eventId":    "submit",
		"geolocation": "",
		"fpVisitorId": fpID,
		"trustAgent":  trustAgent,
		"submit1":     "Login1",
	}

	// Let resty auto-follow redirects (default). After CAS login, the redirect chain
	// goes through CAS → xkfw and sets all session cookies in the jar automatically.
	resp, err := client.R().
		SetHeader("Content-Type", "application/x-www-form-urlencoded").
		SetFormData(data).
		Post(casURL)
	if err != nil {
		return fmt.Errorf("CAS登录请求失败: %w", err)
	}

	if resp.StatusCode() == http.StatusUnauthorized {
		failCount++
		return fmt.Errorf("登录失败：用户名或密码错误")
	}


	body := resp.Body()

	// Check for alert error
	if msg := extractAlertMessage(body); msg != "" {
		failCount++
		return fmt.Errorf("登录失败: %s", msg)
	}

	// Check for Safety Verify page
	if isSafetyVerifyPage(body) {
		secState := extractInputValue(body, "secState")
		secExec := extractExecution(body)
		safetyVerifyURL = resp.Request.URL
		safetyVerifyExecution = secExec
		safetyVerifySecState = secState

		currentMFA = &MFAInfo{State: secState, Flow: MFAFlowSec}
		SetPendingMFAState(secState)

		return &MFANeededError{State: secState, Reason: "需要二次安全认证", IsMFA: true, IsSafetyVerify: true}
	}

	// Check for account choice page
	choices := extractAccountChoices(body)
	if choices != nil {
		accountChoiceExecution = extractExecution(body)
		accountChoices = choices
		failCount++
		return &AccountChoiceNeededError{Choices: choices}
	}

	// Success — resty already followed the redirect chain to xkfw.
	// Session cookies are in the jar. Call register.do directly.
	return doRegister(client)
}

// postCASRaw submits the CAS login form using raw net/http client,
// which properly stores cookies in the cookie jar during redirects.
func postCASRaw(httpClient *http.Client, casURL, account, encPwd, execution, mfaState, fpID, captcha, trustAgent string) error {
	form := url.Values{
		"username":    {account},
		"password":    {encPwd},
		"captcha":     {captcha},
		"currentMenu": {"1"},
		"failN":       {fmt.Sprintf("%d", failCount)},
		"mfaState":    {mfaState},
		"execution":   {execution},
		"_eventId":    {"submit"},
		"geolocation": {""},
		"fpVisitorId": {fpID},
		"trustAgent":  {trustAgent},
		"submit1":     {"Login1"},
	}

	req, err := http.NewRequest("POST", casURL, strings.NewReader(form.Encode()))
	if err != nil {
		return fmt.Errorf("创建CAS请求失败: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("CAS登录请求失败: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized {
		failCount++
		return fmt.Errorf("登录失败：用户名或密码错误")
	}

	// Read body
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()

	// CAS may return reCAPTCHA page instead of redirect
	if isCaptchaPage(body) {
		failCount++
		return &CaptchaNeededError{}
	}

	// Check for alert error
	if msg := extractAlertMessage(body); msg != "" {
		failCount++
		return fmt.Errorf("登录失败: %s", msg)
	}

	// Check for Safety Verify page
	if isSafetyVerifyPage(body) {
		secState := extractInputValue(body, "secState")
		secExec := extractExecution(body)
		safetyVerifyURL = resp.Request.URL.String()
		safetyVerifyExecution = secExec
		safetyVerifySecState = secState

		currentMFA = &MFAInfo{State: secState, Flow: MFAFlowSec}
		SetPendingMFAState(secState)

		return &MFANeededError{State: secState, Reason: "需要二次安全认证", IsMFA: true, IsSafetyVerify: true}
	}

	// Check for account choice page
	choices := extractAccountChoices(body)
	if choices != nil {
		accountChoiceExecution = extractExecution(body)
		accountChoices = choices
		failCount++
		return &AccountChoiceNeededError{Choices: choices}
	}

	// Success — call register
	regURL := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/student/register.do?number=null", baseURL)
	regResp, err := httpClient.Get(regURL)
	if err != nil {
		return fmt.Errorf("注册请求失败: %w", err)
	}
	defer regResp.Body.Close()
	regBody, _ := io.ReadAll(regResp.Body)

	var j struct {
		Code interface{} `json:"code"`
		Data struct {
			Token  string `json:"token"`
			Number string `json:"number"`
		} `json:"data"`
	}
	json.Unmarshal(regBody, &j)

	if !codeIsOK(j.Code) {
		// Try with account
		regURL = fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/student/register.do?number=%s", baseURL, session.Get().Account)
		regResp2, err := httpClient.Get(regURL)
		if err == nil {
			defer regResp2.Body.Close()
			regBody2, _ := io.ReadAll(regResp2.Body)
			json.Unmarshal(regBody2, &j)
		}
	}
	if !codeIsOK(j.Code) {
		return fmt.Errorf("注册失败: 无法获取token, 响应=%s", string(regBody))
	}

	if j.Data.Token != "" {
		session.SetToken(j.Data.Token)
	}
	if j.Data.Number != "" {
		session.SetStudentCode(j.Data.Number)
	}

	ResetFailCount()
	session.SaveCookiesFromHTTP(httpClient)
	return nil
}

type MFANeededError struct {
	State          string `json:"state"`
	Reason         string `json:"reason"`
	IsMFA          bool   `json:"isMfa"`
	IsSafetyVerify bool   `json:"isSafetyVerify"`
}

func (e *MFANeededError) Error() string { return e.Reason }

type CaptchaNeededError struct{}

func (e *CaptchaNeededError) Error() string { return "需要验证码" }

type AccountChoiceNeededError struct {
	Choices []map[string]string `json:"choices"`
}

func (e *AccountChoiceNeededError) Error() string { return "需要选择账户身份" }

func ChooseAccount(client *resty.Client, accountType string) error {
	if len(accountChoices) == 0 || accountChoiceExecution == "" {
		return fmt.Errorf("没有待处理的账户选择")
	}

	// match: "本科" for undergraduate, "研究" for postgraduate
	matchKeyword := "研究" // default postgraduate
	if accountType == "undergraduate" {
		matchKeyword = "本科"
	}

	var selectedLabel string
	for _, c := range accountChoices {
		if strings.Contains(c["name"], matchKeyword) {
			selectedLabel = c["label"]
			break
		}
	}
	if selectedLabel == "" && len(accountChoices) > 0 {
		selectedLabel = accountChoices[0]["label"] // fallback
	}

	fpID := session.Get().FpVisitorID

	resp, err := client.R().
		SetHeader("Content-Type", "application/x-www-form-urlencoded").
		SetFormData(map[string]string{
			"execution":   accountChoiceExecution,
			"_eventId":    "submit",
			"geolocation": "",
			"fpVisitorId": fpID,
			"trustAgent":  "true",
			"username":    selectedLabel,
			"useDefault":  "false",
		}).
		Post(casBaseURL + "/cas/login")
	if err != nil {
		return fmt.Errorf("账户选择请求失败: %w", err)
	}

	// clear stored state
	accountChoiceExecution = ""
	accountChoices = nil

	if msg := extractAlertMessage(resp.Body()); msg != "" {
		return fmt.Errorf("账户选择失败: %s", msg)
	}

	return followAndRegister(client, "")
}

func GetCaptchaImage(client *resty.Client) ([]byte, error) {
	resp, err := client.R().Get(casBaseURL + "/cas/captcha.jpg")
	if err != nil {
		return nil, fmt.Errorf("获取验证码失败: %w", err)
	}
	return resp.Body(), nil
}

// ── MFA completion (after user verifies code) ──

// CompleteMFALogin finishes login after regular MFA verification.
func CompleteMFALogin(client *resty.Client) error {
	return followAndRegister(client, baseURL)
}

// FinishSafetyVerifyLogin submits the Safety Verify form after MFA verification.
func FinishSafetyVerifyLogin(client *resty.Client) error {
	if safetyVerifyURL == "" {
		return fmt.Errorf("没有待处理的Safety Verify")
	}

	fpID := session.Get().FpVisitorID

	resp, err := client.R().
		SetHeader("Content-Type", "application/x-www-form-urlencoded").
		SetFormData(map[string]string{
			"secState":    safetyVerifySecState,
			"execution":   safetyVerifyExecution,
			"_eventId":    "submit",
			"geolocation": "",
			"fpVisitorId": fpID,
			"submit":      "Login1",
		}).
		Post(safetyVerifyURL)
	if err != nil {
		return fmt.Errorf("Safety Verify提交失败: %w", err)
	}

	ClearSafetyVerify()

	if resp.StatusCode() == http.StatusUnauthorized {
		return fmt.Errorf("二次认证失败")
	}
	if isSafetyVerifyPage(resp.Body()) {
		return fmt.Errorf("二次认证未通过，请重试")
	}
	if msg := extractAlertMessage(resp.Body()); msg != "" {
		return fmt.Errorf("二次认证失败: %s", msg)
	}

	return followAndRegister(client, "")
}

func ClearSafetyVerify() {
	safetyVerifyURL = ""
	safetyVerifyExecution = ""
	safetyVerifySecState = ""
}

// ── HTML parsing helpers ──

func isSafetyVerifyPage(htmlContent []byte) bool {
	s := string(htmlContent)
	return strings.Contains(s, "secState") &&
		strings.Contains(s, "execution") &&
		strings.Contains(s, "_eventId") &&
		(strings.Contains(s, "Safety Verify") ||
			strings.Contains(s, "/cas/sec/initByType") ||
			strings.Contains(s, "选择安全认证") ||
			strings.Contains(s, "二次认证"))
}

func extractExecution(html []byte) string {
	return extractInputValue(html, "execution")
}

func extractInputValue(html []byte, name string) string {
	s := string(html)
	search := fmt.Sprintf(`name="%s"`, name)
	idx := strings.Index(s, search)
	if idx < 0 {
		return ""
	}
	valIdx := strings.Index(s[idx:], `value="`)
	if valIdx < 0 {
		return ""
	}
	valIdx += len(`value="`)
	end := strings.Index(s[idx+valIdx:], `"`)
	if end < 0 {
		return ""
	}
	return s[idx+valIdx : idx+valIdx+end]
}

func codeIsOK(code interface{}) bool {
	switch v := code.(type) {
	case float64:
		return v == 0 || v == 1
	case string:
		return v == "0" || v == "1"
	}
	return false
}

func extractAlertMessage(htmlContent []byte) string {
	s := string(htmlContent)
	idx := strings.Index(s, "el-alert")
	if idx < 0 {
		return ""
	}
	titleIdx := strings.Index(s[idx:], `title="`)
	if titleIdx < 0 {
		return ""
	}
	titleIdx += len(`title="`)
	end := strings.Index(s[idx+titleIdx:], `"`)
	if end < 0 {
		return ""
	}
	return s[idx+titleIdx : idx+titleIdx+end]
}

func extractAccountChoices(htmlContent []byte) []map[string]string {
	s := string(htmlContent)
	if !strings.Contains(s, "account-wrap") {
		return nil
	}
	var choices []map[string]string
	// crude extraction: find name divs and radio labels
	for {
		wrapIdx := strings.Index(s, "account-wrap")
		if wrapIdx < 0 {
			break
		}
		s = s[wrapIdx:]
		nameStart := strings.Index(s, `class="name"`)
		if nameStart < 0 {
			break
		}
		nameStart = strings.Index(s[nameStart:], ">") + nameStart + 1
		nameEnd := strings.Index(s[nameStart:], "<")
		name := strings.TrimSpace(s[nameStart : nameStart+nameEnd])

		labelIdx := strings.Index(s, `label="`)
		if labelIdx < 0 {
			break
		}
		labelIdx += len(`label="`)
		labelEnd := strings.Index(s[labelIdx:], `"`)
		label := s[labelIdx : labelIdx+labelEnd]

		choices = append(choices, map[string]string{"name": name, "label": label})
		s = s[nameStart+nameEnd:]
		if len(s) < 100 {
			break
		}
	}
	return choices
}

func detectMFA(client *resty.Client, account, encPwd, fpID string) (need bool, state string, err error) {
	data := map[string]string{
		"username":    account,
		"password":    encPwd,
		"fpVisitorId": fpID,
	}
	resp, err := client.R().
		SetHeader("Content-Type", "application/x-www-form-urlencoded").
		SetFormData(data).
		Post(casBaseURL + "/cas/mfa/detect")
	if err != nil {
		return false, "", err
	}
	var j struct {
		Code int `json:"code"`
		Data struct {
			Need  bool   `json:"need"`
			State string `json:"state"`
		} `json:"data"`
	}
	if err := json.Unmarshal(resp.Body(), &j); err != nil {
		return false, "", err
	}
	return j.Data.Need, j.Data.State, nil
}

// ── follow redirects & register ──

// doRegister calls the xkfw register endpoint directly.
// Session cookies must already be in the client's jar (from CAS redirect chain).
func doRegister(client *resty.Client) error {
	s := session.Get()

	regURL := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/student/register.do?number=null", baseURL)
	r, err := client.R().Get(regURL)
	if err != nil {
		return fmt.Errorf("注册请求失败: %w", err)
	}

	var j struct {
		Code interface{} `json:"code"`
		Data struct {
			Token  string `json:"token"`
			Number string `json:"number"`
		} `json:"data"`
	}
	json.Unmarshal(r.Body(), &j)

	if !codeIsOK(j.Code) {
		regURL = fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/student/register.do?number=%s", baseURL, s.Account)
		r, err = client.R().Get(regURL)
		if err == nil {
			json.Unmarshal(r.Body(), &j)
		}
	}
	if !codeIsOK(j.Code) {
		return fmt.Errorf("注册失败: 无法获取token, 响应=%s", string(r.Body()))
	}

	if j.Data.Token != "" {
		session.SetToken(j.Data.Token)
		client.SetHeader("Token", j.Data.Token)
	}
	if j.Data.Number != "" {
		session.SetStudentCode(j.Data.Number)
	}

	ResetFailCount()
	session.SaveCookies(client)
	return nil
}

// followAndRegister follows a CAS redirect chain manually, then registers.
func followAndRegister(client *resty.Client, startURL string) error {
	if startURL == "" {
		startURL = baseURL
	}
	url := startURL
	s := session.Get()
	var studentCode string

	client.SetRedirectPolicy(resty.RedirectPolicyFunc(func(req *http.Request, via []*http.Request) error {
		return http.ErrUseLastResponse
	}))

	for i := 0; i < 10; i++ {
		resp, err := client.R().Get(url)
		if err != nil {
			return fmt.Errorf("重定向链请求失败: %w", err)
		}
		if resp.StatusCode() != http.StatusFound && resp.StatusCode() != http.StatusMovedPermanently {
			if resp.StatusCode() == http.StatusOK && strings.Contains(resp.Request.URL, "xkfw.xjtu.edu.cn") {
				break
			}
			break
		}
		loc := resp.Header().Get("Location")
		if loc == "" {
			break
		}
		if strings.Contains(loc, "employeeNo=") {
			parts := strings.Split(loc, "employeeNo=")
			if len(parts) > 1 {
				studentCode = strings.Split(parts[1], "&")[0]
			}
			client.R().Get(loc)
			break
		}
		url = loc
	}

	client.SetRedirectPolicy(resty.RedirectPolicyFunc(nil))

	regCode := studentCode
	if regCode == "" {
		regCode = "null"
	}
	regURL := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/student/register.do?number=%s", baseURL, regCode)
	r, err := client.R().Get(regURL)
	if err != nil {
		return fmt.Errorf("注册请求失败: %w", err)
	}

	var j struct {
		Code interface{} `json:"code"`
		Data struct {
			Token  string `json:"token"`
			Number string `json:"number"`
		} `json:"data"`
	}
	json.Unmarshal(r.Body(), &j)

	if !codeIsOK(j.Code) && regCode == "null" {
		regURL = fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/student/register.do?number=%s", baseURL, s.Account)
		r, err = client.R().Get(regURL)
		if err == nil {
			json.Unmarshal(r.Body(), &j)
		}
	}
	if !codeIsOK(j.Code) {
		return fmt.Errorf("注册失败: 无法获取token, 响应=%s", string(r.Body()))
	}

	if j.Data.Token != "" {
		session.SetToken(j.Data.Token)
		client.SetHeader("Token", j.Data.Token)
	}
	if j.Data.Number != "" {
		session.SetStudentCode(j.Data.Number)
	}

	ResetFailCount()
	session.SaveCookies(client)
	return nil
}

