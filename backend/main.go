package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"xjtu-course-genius/internal/api"
)

func main() {
	router := api.NewRouter()

	port := "18720"
	if p := os.Getenv("PORT"); p != "" {
		port = p
	}

	fmt.Printf("XJTU Course Genius backend listening on http://127.0.0.1:%s\n", port)
	log.Fatal(http.ListenAndServe("127.0.0.1:"+port, router))
}
