package auth

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/go-resty/resty/v2"
)

type MFAFlow string

const (
	MFAFlowMFA   MFAFlow = "mfa"
	MFAFlowSec   MFAFlow = "sec"
)

type MFAInfo struct {
	Type            string  `json:"type"` // "securephone" or "secureemail"
	State           string  `json:"state"`
	GID             string  `json:"gid"`
	AttestServerURL string  `json:"attestServerUrl"`
	SecurePhone     string  `json:"securePhone,omitempty"`
	SecureEmail     string  `json:"secureEmail,omitempty"`
	Flow            MFAFlow `json:"flow"`
}

var currentMFA *MFAInfo
var pendingMFAState string

func SetPendingMFAState(s string)  { pendingMFAState = s }
func GetMFA() *MFAInfo             { return currentMFA }
func IsSafetyVerifyFlow() bool     { return currentMFA != nil && currentMFA.Flow == MFAFlowSec }

type MFAInitPayload struct {
	Method string `json:"method"` // "securephone" or "secureemail"
}

type MFAInitResult struct {
	Target string `json:"target"` // obscured phone or email
	Type   string `json:"type"`
}

func InitMFA(client *resty.Client, mfaType string) (*MFAInitResult, error) {
	mfaState := pendingMFAState
	if mfaState == "" && currentMFA != nil {
		mfaState = currentMFA.State
	}
	if mfaState == "" {
		return nil, fmt.Errorf("没有可用的MFA状态，请先登录")
	}

	flow := MFAFlowMFA
	if currentMFA != nil && currentMFA.Flow == MFAFlowSec {
		flow = MFAFlowSec
	}

	url := fmt.Sprintf("https://login.xjtu.edu.cn/cas/%s/initByType/%s?state=%s", flow, mfaType, mfaState)
	resp, err := client.R().Get(url)
	if err != nil {
		return nil, fmt.Errorf("MFA初始化失败: %w", err)
	}

	var j struct {
		Code int `json:"code"`
		Data struct {
			GID             string `json:"gid"`
			AttestServerURL string `json:"attestServerUrl"`
			SecurePhone     string `json:"securePhone"`
			SecureEmail     string `json:"secureEmail"`
		} `json:"data"`
	}
	if err := json.Unmarshal(resp.Body(), &j); err != nil {
		return nil, fmt.Errorf("解析MFA初始化响应失败: %w", err)
	}
	if j.Code != 0 {
		return nil, fmt.Errorf("MFA初始化失败: code=%d", j.Code)
	}

	currentMFA = &MFAInfo{
		Type:            mfaType,
		State:           mfaState,
		GID:             j.Data.GID,
		AttestServerURL: j.Data.AttestServerURL,
		SecurePhone:     j.Data.SecurePhone,
		SecureEmail:     j.Data.SecureEmail,
		Flow:            flow,
	}

	result := &MFAInitResult{Type: mfaType}
	if mfaType == "securephone" {
		result.Target = j.Data.SecurePhone
	} else {
		result.Target = j.Data.SecureEmail
	}
	return result, nil
}

func SendMFACode(client *resty.Client) error {
	if currentMFA == nil {
		return fmt.Errorf("MFA未初始化")
	}
	url := fmt.Sprintf("%s/api/guard/%s/send", currentMFA.AttestServerURL, currentMFA.Type)
	data := map[string]string{"gid": currentMFA.GID}
	resp, err := client.R().SetBody(data).Post(url)
	if err != nil {
		return fmt.Errorf("发送验证码失败: %w", err)
	}
	var j struct {
		Code int `json:"code"`
		Data struct {
			Result string `json:"result"`
		} `json:"data"`
	}
	json.Unmarshal(resp.Body(), &j)
	if j.Code != 0 {
		if j.Data.Result == "expired" {
			// re-init and try again after 500ms
			time.Sleep(500 * time.Millisecond)
			if _, err := InitMFA(client, currentMFA.Type); err != nil {
				return err
			}
			return SendMFACode(client)
		}
		return fmt.Errorf("发送验证码失败")
	}
	return nil
}

func VerifyMFACode(client *resty.Client, code string) error {
	if currentMFA == nil {
		return fmt.Errorf("MFA未初始化")
	}
	url := fmt.Sprintf("%s/api/guard/%s/valid", currentMFA.AttestServerURL, currentMFA.Type)
	data := map[string]string{"gid": currentMFA.GID, "code": code}
	resp, err := client.R().SetBody(data).Post(url)
	if err != nil {
		return fmt.Errorf("验证码校验失败: %w", err)
	}
	var j struct {
		Code int `json:"code"`
		Data struct {
			Status int `json:"status"`
		} `json:"data"`
	}
	if err := json.Unmarshal(resp.Body(), &j); err != nil {
		return fmt.Errorf("解析验证响应失败: %w", err)
	}
	if j.Code == 0 && j.Data.Status == 2 {
		return nil
	}
	return fmt.Errorf("验证码错误")
}

func ClearMFA() { currentMFA = nil }
