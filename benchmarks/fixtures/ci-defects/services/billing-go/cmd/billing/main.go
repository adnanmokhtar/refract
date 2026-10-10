package main

import (
	"log"
	"net/http"
	"os"

	"github.com/acme/shop/services/billing-go/internal/invoices"
)

var version = "dev"

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	mux.Handle("/invoices/", invoices.Handler(os.Getenv("BILLING_DB_URL")))

	log.Printf("billing %s listening on :8080", version)
	log.Fatal(http.ListenAndServe(":8080", mux))
}
