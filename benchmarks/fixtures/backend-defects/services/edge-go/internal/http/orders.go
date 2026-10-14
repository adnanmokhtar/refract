package edgehttp

import (
	"net/http"
	"runtime/debug"

	"github.com/gin-gonic/gin"
)

type createOrderRequest struct {
	CartID  string `json:"cartId" binding:"required,uuid"`
	Payment string `json:"paymentMethodId" binding:"required"`
}

// CreateOrder turns a cart into an order through the API service.
func CreateOrder(c *gin.Context) {
	var req createOrderRequest
	if err := c.Bind(&req); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"error": gin.H{"code": "VALIDATION", "message": "invalid order"}})
		return
	}
	id, err := placeOrder(c.Request.Context(), req.CartID, req.Payment)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error(), "stack": string(debug.Stack())})
		return
	}
	c.Header("Location", "/v1/orders/"+id)
	c.JSON(http.StatusCreated, gin.H{"data": gin.H{"id": id}})
}
