package main

import (
	"encoding/json"
	"html/template"
	"log"
	"net/http"
	"os"
	"runtime"
	"time"
)

type HealthResponse struct {
	Status    string    `json:"status"`
	Timestamp time.Time `json:"timestamp"`
	Version   string    `json:"version"`
	Uptime    string    `json:"uptime"`
}

type ReadyResponse struct {
	Status  string `json:"status"`
	Checks  map[string]bool `json:"checks"`
}

type MetricsResponse struct {
	MemoryUsage    uint64 `json:"memory_usage"`
	GoroutineCount int    `json:"goroutine_count"`
	RequestCount   int64  `json:"request_count"`
}

var (
	startTime = time.Now()
	requestCount int64
)

func renderTemplate(w http.ResponseWriter, tmpl string) {
	t, err := template.ParseFiles("templates/" + tmpl)
	if err != nil {
		http.Error(w, "Page not found", http.StatusNotFound)
		return
	}

	if err := t.Execute(w, nil); err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	uptime := time.Since(startTime)
	response := HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now(),
		Version:   "1.0.0",
		Uptime:    uptime.String(),
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
	checks := map[string]bool{
		"database": true, // In real app, check DB connection
		"redis":    true, // In real app, check Redis connection
		"external": true, // In real app, check external services
	}
	
	allReady := true
	for _, check := range checks {
		if !check {
			allReady = false
			break
		}
	}
	
	status := "ready"
	if !allReady {
		status = "not_ready"
		w.WriteHeader(http.StatusServiceUnavailable)
	}
	
	response := ReadyResponse{
		Status: status,
		Checks: checks,
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	
	response := MetricsResponse{
		MemoryUsage:    m.Alloc,
		GoroutineCount: runtime.NumGoroutine(),
		RequestCount:   requestCount,
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func middleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		requestCount++
		
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		
		next(w, r)
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))

	http.HandleFunc("/", middleware(func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "index.html")
	}))

	http.HandleFunc("/login", middleware(func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "login.html")
	}))

	http.HandleFunc("/signup", middleware(func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "signup.html")
	}))

	http.HandleFunc("/product", middleware(func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "product.html")
	}))

	http.HandleFunc("/about", middleware(func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "about.html")
	}))

	http.HandleFunc("/dashboard", middleware(func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "dashboard.html")
	}))

	http.HandleFunc("/health", middleware(healthHandler))
	http.HandleFunc("/ready", middleware(readyHandler))
	http.HandleFunc("/metrics", middleware(metricsHandler))

	log.Printf("Server running on :%s", port)
	log.Printf("Environment: %s", os.Getenv("ENVIRONMENT"))
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
