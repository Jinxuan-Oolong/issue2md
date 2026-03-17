package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"

	"github.com/Jinxuan-Oolong/my-issue2md-project/web/handlers"
)

func main() {
	// Define command-line flags
	ip := flag.String("ip", "0.0.0.0", "IP address to bind to")
	port := flag.Int("port", 8080, "Port to listen on")

	// Parse the flags
	flag.Parse()

	http.HandleFunc("/", handlers.HomeHandler)
	http.HandleFunc("/convert", handlers.ConvertHandler)

	// Serve static files
	fs := http.FileServer(http.Dir("web/static"))
	http.Handle("/static/", http.StripPrefix("/static/", fs))

	addr := fmt.Sprintf("%s:%d", *ip, *port)
	fmt.Printf("Server is running on http://%s\n", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
