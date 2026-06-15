package session

import (
	"math/rand"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"sync"
	"time"

	"github.com/go-resty/resty/v2"
)

var uaList = []string{
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36 Edg/128.0.0.0",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0",
}

func randomUA() string {
	return uaList[rand.Intn(len(uaList))]
}

type State struct {
	Account      string
	Password     string
	StudentCode  string
	BatchCode    string // xklcdm (elective batch code)
	BatchType    string // typeCode: "02"=正选
	Campus       string
	CampusList   []CampusInfo
	Token        string
	Cookies      []*http.Cookie
	FpVisitorID  string

	mu sync.Mutex
}

type CampusInfo struct {
	Code string `json:"code"`
	Name string `json:"name"`
}

var state = &State{}

func Get() *State { return state }

func NewClient() *resty.Client {
	jar, _ := cookiejar.New(nil)
	client := resty.New().
		SetCookieJar(jar).
		SetTimeout(15 * time.Second).
		SetHeader("User-Agent", randomUA()).
		SetHeader("Accept", "application/json, text/plain, */*").
		SetHeader("Accept-Language", "zh-CN,zh;q=0.9")

	// load saved cookies
	xkfwURL, _ := url.Parse("https://xkfw.xjtu.edu.cn")
	casURL, _ := url.Parse("https://login.xjtu.edu.cn")
	for _, c := range state.Cookies {
		client.GetClient().Jar.SetCookies(xkfwURL, []*http.Cookie{c})
		client.GetClient().Jar.SetCookies(casURL, []*http.Cookie{c})
	}
	if state.Token != "" {
		client.SetHeader("Token", state.Token)
	}
	return client
}

var allCookiesURLs = []*url.URL{
	{Scheme: "https", Host: "xkfw.xjtu.edu.cn"},
	{Scheme: "https", Host: "login.xjtu.edu.cn"},
}

func jarCookies(jar http.CookieJar) []*http.Cookie {
	if jar == nil {
		return nil
	}
	var all []*http.Cookie
	for _, u := range allCookiesURLs {
		all = append(all, jar.Cookies(u)...)
	}
	return all
}

func SaveCookies(client *resty.Client) {
	state.mu.Lock()
	defer state.mu.Unlock()
	state.Cookies = jarCookies(client.GetClient().Jar)
}

func SaveCookiesFromHTTP(httpClient *http.Client) {
	state.mu.Lock()
	defer state.mu.Unlock()
	if httpClient.Jar != nil {
		state.Cookies = jarCookies(httpClient.Jar)
	}
}

func SetToken(t string) {
	state.mu.Lock()
	state.Token = t
	state.mu.Unlock()
}

func SetStudentCode(code string) {
	state.mu.Lock()
	state.StudentCode = code
	state.mu.Unlock()
}

func SetBatchCode(code string) {
	state.mu.Lock()
	state.BatchCode = code
	state.mu.Unlock()
}

func SetBatchType(tc string) {
	state.mu.Lock()
	state.BatchType = tc
	state.mu.Unlock()
}

func SetCampus(c string) {
	state.mu.Lock()
	state.Campus = c
	state.mu.Unlock()
}

func SetCampusList(list []CampusInfo) {
	state.mu.Lock()
	state.CampusList = list
	state.mu.Unlock()
}

func SetFpVisitorID(id string) {
	state.mu.Lock()
	state.FpVisitorID = id
	state.mu.Unlock()
}
