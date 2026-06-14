package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"

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
	// Write logs to both stderr (console) and file
	multiWriter := io.MultiWriter(os.Stderr, f)
	log.SetOutput(multiWriter)
	log.SetFlags(log.Ldate | log.Ltime)
	fmt.Fprintf(os.Stderr, "Log file: %s\n", path)
	return f
}

func main() {
	logFile := setupLogging()
	if logFile != nil {
		defer logFile.Close()
	}

	log.Println("[main] XJTU Course Genius backend starting")

	router := api.NewRouter()

	port := "18720"
	if p := os.Getenv("PORT"); p != "" {
		port = p
	}

	fmt.Printf("XJTU Course Genius backend listening on http://127.0.0.1:%s\n", port)
	log.Printf("[main] listening on http://127.0.0.1:%s", port)
	log.Fatal(http.ListenAndServe("127.0.0.1:"+port, router))
}
