package edgehttp

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type checkoutRequest struct {
	CartID      string `json:"cartId" binding:"required,uuid"`
	TipPercent  *int   `json:"tipPercent" binding:"required,min=0,max=30"`
	LeaveAtDoor *bool  `json:"leaveAtDoor" binding:"required"`
}

// Checkout validates the final basket. Validation failures answer 422 in the envelope (openapi
// documents 422 for /v1/checkout: the storefront shows per-field messages from `details`).
func Checkout(c *gin.Context) {
	var req checkoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"error": gin.H{"code": "VALIDATION", "message": "invalid checkout", "details": []string{err.Error()}}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"cartId": req.CartID, "tipPercent": *req.TipPercent, "leaveAtDoor": *req.LeaveAtDoor}})
}
