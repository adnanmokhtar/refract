package main

import (
	"context"
	"database/sql"
	"log"
	"os"

	_ "github.com/lib/pq"
	"tollgate.dev/ingest"
)

// replay re-records events from an on-call replay file in one batch.
func main() {
	ids, err := ingest.LoadReplayIDs(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	db, err := sql.Open("postgres", os.Getenv("INGEST_DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	batch := make([]ingest.Event, 0, len(ids))
	for _, id := range ids {
		batch = append(batch, ingest.Event{ID: id, Kind: "replay"})
	}
	if err := ingest.NewStore(db).SaveBatch(context.Background(), batch); err != nil {
		log.Fatal(err)
	}
	log.Printf("replayed %d events", len(batch))
}
