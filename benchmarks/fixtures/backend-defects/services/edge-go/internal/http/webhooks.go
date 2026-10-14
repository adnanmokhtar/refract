package edgehttp

import (
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
)

type carrierEvent struct {
	ShipmentID string `json:"shipmentId"`
	Status     string `json:"status"`
}

// CarrierWebhook ingests carrier tracking events. Provider webhooks are tolerant readers
// (ai/api-conventions.md § Request bodies): carriers add fields without notice.
func CarrierWebhook(c *gin.Context) {
	var ev carrierEvent
	if err := json.NewDecoder(c.Request.Body).Decode(&ev); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": gin.H{"code": "MALFORMED_JSON", "message": "body is not valid JSON"}})
		return
	}
	c.Status(http.StatusNoContent)
}
