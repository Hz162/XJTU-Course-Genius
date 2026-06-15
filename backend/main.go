package main

import (
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"

	"xjtu-course-genius/internal/api"
)

func setupLogging() *os.File {
	exe, _ := os.Executable()
	dir := filepath.Dir(exe)
	path := filepath.Join(dir, "xjtu-genius.log")

	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return nil
	}
	multiWriter := io.MultiWriter(os.Stderr, f)
	log.SetOutput(multiWriter)
	log.SetFlags(log.Ldate | log.Ltime)
	fmt.Fprintf(os.Stderr, "Log file: %s\n", path)
	return f
}

func configDir() string {
	var dir string
	switch runtime.GOOS {
	case "windows":
		dir = os.Getenv("APPDATA")
		if dir == "" {
			dir = filepath.Join(os.Getenv("USERPROFILE"), "AppData", "Roaming")
		}
	case "darwin":
		dir = filepath.Join(os.Getenv("HOME"), "Library", "Application Support")
	default:
		dir = os.Getenv("XDG_CONFIG_HOME")
		if dir == "" {
			dir = filepath.Join(os.Getenv("HOME"), ".config")
		}
	}
	return filepath.Join(dir, "xjtu-genius")
}

func writePortFile(port string) {
	dir := configDir()
	if err := os.MkdirAll(dir, 0755); err != nil {
		log.Printf("[main] failed to create config dir: %v", err)
		return
	}
	path := filepath.Join(dir, "port")
	if err := os.WriteFile(path, []byte(port), 0644); err != nil {
		log.Printf("[main] failed to write port file: %v", err)
	} else {
		log.Printf("[main] port written to %s", path)
		fmt.Fprintf(os.Stderr, "Port file: %s\n", path)
	}
}

func findAvailablePort(preferred string) string {
	// Parse preferred port
	p, err := strconv.Atoi(preferred)
	if err != nil {
		p = 18720
	}

	// Try up to 100 ports starting from preferred
	for i := 0; i < 100; i++ {
		port := strconv.Itoa(p + i)
		addr := "127.0.0.1:" + port
		ln, err := net.Listen("tcp", addr)
		if err == nil {
			ln.Close()
			return port
		}
		log.Printf("[main] port %s in use, trying next...", port)
	}

	// Last resort: let the OS pick
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		log.Fatalf("[main] no available port: %v", err)
	}
	defer ln.Close()
	_, port, _ := net.SplitHostPort(ln.Addr().String())
	return port
}

func main() {
	logFile := setupLogging()
	if logFile != nil {
		defer logFile.Close()
	}

	log.Println("[main] XJTU Course Genius backend starting")

	router := api.NewRouter()

	preferred := "18720"
	if p := os.Getenv("PORT"); p != "" {
		preferred = p
	}

	port := findAvailablePort(preferred)
	writePortFile(port)

	addr := "127.0.0.1:" + port
	// Machine-readable port announcement — Flutter subprocess parses this
	fmt.Printf("PORT=%s\n", port)
	fmt.Printf("XJTU Course Genius backend listening on http://%s\n", addr)
	log.Printf("[main] listening on http://%s", addr)

	log.Fatal(http.ListenAndServe(addr, router))
}
