package main

import (
	"html/template"
	"log"
	"net/http"
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


func main() {
	http.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "index.html")
	})

	http.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "login.html")
	})

	http.HandleFunc("/signup", func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "signup.html")
	})

	http.HandleFunc("/product", func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "product.html")
	})

	http.HandleFunc("/about", func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "about.html")
	})

	http.HandleFunc("/dashboard", func(w http.ResponseWriter, r *http.Request) {
		renderTemplate(w, "dashboard.html")
	})

	log.Println("Server running on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
