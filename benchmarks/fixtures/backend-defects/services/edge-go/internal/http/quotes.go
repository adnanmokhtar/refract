package edgehttp

import (
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
)

type createQuoteRequest struct {
	Currency     string `json:"currency"`
	PostalCode   string `json:"postalCode"`
	ExpressShip  bool   `json:"expressShipping"`
	GiftWrapping bool   `json:"giftWrapping"`
}

// CreateQuote prices delivery for a basket (public API: strict reader per ai/api-conventions.md).
func CreateQuote(c *gin.Context) {
	var req createQuoteRequest
	if err := json.NewDecoder(c.Request.Body).Decode(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": gin.H{"code": "MALFORMED_JSON", "message": "body is not valid JSON"}})
		return
	}
	fee := "15.00"
	if req.ExpressShip {
		fee = "35.00"
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"currency": req.Currency, "deliveryFee": fee}})
}
