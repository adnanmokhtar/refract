package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/lib/pq"
	"tollgate.dev/ingest"
)

func main() {
	db, err := sql.Open("postgres", os.Getenv("INGEST_DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	store := ingest.NewStore(db)
	h := ingest.NewHandler(store, ingest.NewDeduper(store), ingest.NewLimiter(50),
		&ingest.HTTPForwarder{Client: &http.Client{Timeout: 10 * time.Second}, URL: os.Getenv("INGEST_FORWARD_URL")})
	mux := http.NewServeMux()
	mux.Handle("POST /provider/events", h)
	mux.HandleFunc("GET /debug/deliveries/{merchant}", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("deliveries=%d throttled=%d", ingest.DeliveryCount(r.PathValue("merchant")), ingest.ThrottledCount(r.PathValue("merchant")))
	})
	log.Fatal(http.ListenAndServe(":8080", mux))
}
