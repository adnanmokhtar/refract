package edgehttp

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type addCartItemRequest struct {
	CartID    string `json:"cartId" binding:"required,uuid"`
	ProductID string `json:"productId" binding:"required,uuid"`
	Qty       int    `json:"qty" binding:"required,min=0,max=99"`
}

// AddCartItem sets the quantity of a product in the cart; qty 0 removes the line.
func AddCartItem(c *gin.Context) {
	var req addCartItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": gin.H{"code": "VALIDATION", "message": err.Error()}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"cartId": req.CartID, "productId": req.ProductID, "qty": req.Qty}})
}
