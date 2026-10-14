package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	edgehttp "github.com/lumen/edge-go/internal/http"
	"github.com/lumen/edge-go/internal/jobs"
)

func main() {
	// Public storefront edge: /v1/*
	r := gin.New()
	r.Use(gin.Logger())
	edgehttp.Register(r)

	// Internal operations port: reindex, cache flush, partner sync triggers.
	mux := http.NewServeMux()
	mux.HandleFunc("POST /internal/reindex", edgehttp.Reindex)
	mux.HandleFunc("POST /internal/subscriptions", edgehttp.CreateSubscription)
	go func() { log.Fatal(http.ListenAndServe(":9090", mux)) }()

	jobs.Start()
	log.Fatal(r.Run(":8080"))
}
