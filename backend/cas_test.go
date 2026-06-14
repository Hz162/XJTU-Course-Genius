//go:build ignore
package main

import (
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"os"
	"strings"
)

func main() {
	jar, _ := cookiejar.New(nil)
	client := &http.Client{Jar: jar}

	// Step 1: GET xkfw -> CAS redirect
	resp, _ := client.Get("https://xkfw.xjtu.edu.cn")
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	casURL := resp.Request.URL.String()
	fmt.Println("CAS URL:", casURL[:80])

	// Extract execution
	s := string(body)
	idx := strings.Index(s, `name="execution"`)
	execution := ""
	if idx >= 0 {
		vidx := strings.Index(s[idx:], `value="`) + idx + 7
		end := strings.Index(s[vidx:], `"`)
		execution = s[vidx : vidx+end]
	}
	fmt.Println("Execution:", execution[:60])

	// Step 2: Get public key
	resp, _ = client.Get("https://login.xjtu.edu.cn/cas/jwt/publicKey")
	pubBody, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	fmt.Println("Public key:", len(pubBody), "bytes")

	// Step 3: Submit wrong password to trigger captcha
	form := url.Values{
		"username":    {"13127086682"},
		"password":    {"__RSA__wrong"},
		"captcha":     {""},
		"currentMenu": {"1"},
		"failN":       {"0"},
		"mfaState":    {""},
		"execution":   {execution},
		"_eventId":    {"submit"},
		"geolocation": {""},
		"fpVisitorId": {""},
		"trustAgent":  {""},
		"submit1":     {"Login1"},
	}

	resp, _ = client.Post(casURL, "application/x-www-form-urlencoded", strings.NewReader(form.Encode()))
	respBody, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	fmt.Println("\nCAS response status:", resp.StatusCode)
	fmt.Println("Location:", resp.Header.Get("Location")[:80])

	// Check for various captcha patterns
	html := string(respBody)
	fmt.Println("\n--- Captcha detection ---")
	fmt.Println("Contains 'recaptcha':", strings.Contains(html, "recaptcha"))
	fmt.Println("Contains 'captcha.jpg':", strings.Contains(html, "captcha.jpg"))
	fmt.Println("Contains 'g-recaptcha':", strings.Contains(html, "g-recaptcha"))
	fmt.Println("Contains 'captcha':", strings.Contains(html, "captcha"))
	fmt.Println("Contains 'fm1':", strings.Contains(html, "fm1"))
	fmt.Println("Contains 'execution':", strings.Contains(html, "execution"))
	fmt.Println("Response length:", len(html))

	// Save for analysis
	os.WriteFile("cas_captcha_response.html", respBody, 0644)
	fmt.Println("\nSaved to cas_captcha_response.html")
}
