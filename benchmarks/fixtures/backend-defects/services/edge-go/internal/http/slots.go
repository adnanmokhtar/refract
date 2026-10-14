package edgehttp

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// ListSlots lists delivery slots after ?from=2026-10-14 09:00 (the store's local time in the UI).
func ListSlots(c *gin.Context) {
	from, err := time.Parse("2006-01-02 15:04", c.Query("from"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": gin.H{"code": "BAD_FROM", "message": "from must be YYYY-MM-DD HH:MM"}})
		return
	}
	slots := []gin.H{}
	for i := 0; i < 4; i++ {
		start := from.Add(time.Duration(i*2) * time.Hour)
		slots = append(slots, gin.H{"start": start.Format(time.RFC3339), "end": start.Add(2 * time.Hour).Format(time.RFC3339)})
	}
	c.JSON(http.StatusOK, gin.H{"data": slots})
}
