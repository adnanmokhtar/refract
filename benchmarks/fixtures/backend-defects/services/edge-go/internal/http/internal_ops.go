package edgehttp

import (
	"encoding/json"
	"net/http"
)

// Reindex triggers a catalog reindex (internal port).
func Reindex(w http.ResponseWriter, r *http.Request) {
	go reindexCatalog()
	w.WriteHeader(http.StatusAccepted)
}

type subscriptionRequest struct {
	PartnerID string `json:"partnerId"`
	Topic     string `json:"topic"`
}

// CreateSubscription registers a partner for an event topic (internal port).
func CreateSubscription(w http.ResponseWriter, r *http.Request) {
	var req subscriptionRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		http.Error(w, `{"error":{"code":"MALFORMED_JSON","message":"invalid body"}}`, http.StatusBadRequest)
	}
	if req.Topic == "" {
		http.Error(w, `{"error":{"code":"TOPIC_REQUIRED","message":"topic is required"}}`, http.StatusBadRequest)
		return
	}
	saveSubscription(req.PartnerID, req.Topic)
	w.Header().Set("Location", "/internal/subscriptions/"+req.PartnerID+"/"+req.Topic)
	w.WriteHeader(http.StatusCreated)
}

func reindexCatalog()                     {}
func saveSubscription(partner, topic string) {}
