package auth

import (
	"crypto/sha256"
	"fmt"
	"net"
	"os"
	"runtime"
	"sort"
	"strings"
	"sync"
)

var (
	cachedVisitorID string
	fpMu            sync.Mutex
	fpInitialized   bool
)

// GetFingerprint generates a stable device fingerprint without browser automation.
// Uses SHA-256 hash of system info (platform, hostname, CPU count, MAC address).
func GetFingerprint() (string, error) {
	fpMu.Lock()
	if fpInitialized && cachedVisitorID != "" {
		v := cachedVisitorID
		fpMu.Unlock()
		return v, nil
	}
	fpMu.Unlock()

	info := map[string]string{
		"platform":  runtime.GOOS + "/" + runtime.GOARCH,
		"hostname":  hostname(),
		"numCPU":    fmt.Sprintf("%d", runtime.NumCPU()),
		"mac":       firstMAC(),
	}

	keys := make([]string, 0, len(info))
	for k := range info {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var sb strings.Builder
	for i, k := range keys {
		if i > 0 {
			sb.WriteString("|")
		}
		sb.WriteString(k)
		sb.WriteString(":")
		sb.WriteString(info[k])
	}

	hash := sha256.Sum256([]byte(sb.String()))
	visitorID := fmt.Sprintf("%x", hash)[:32]

	fpMu.Lock()
	cachedVisitorID = visitorID
	fpInitialized = true
	fpMu.Unlock()

	return visitorID, nil
}

func hostname() string {
	h, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return h
}

func firstMAC() string {
	ifaces, err := net.Interfaces()
	if err != nil {
		return "00:00:00:00:00:00"
	}
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		if mac := iface.HardwareAddr.String(); mac != "" {
			return mac
		}
	}
	return "00:00:00:00:00:00"
}

func ResetFingerprint() {
	fpMu.Lock()
	cachedVisitorID = ""
	fpInitialized = false
	fpMu.Unlock()
}
