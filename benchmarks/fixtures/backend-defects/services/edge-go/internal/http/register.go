package edgehttp

import "github.com/gin-gonic/gin"

// Register mounts the public /v1 routes.
func Register(r *gin.Engine) {
	v1 := r.Group("/v1")
	v1.POST("/cart/items", AddCartItem)
	v1.POST("/quotes", CreateQuote)
	v1.POST("/orders", CreateOrder)
	v1.GET("/slots", ListSlots)
	v1.POST("/checkout", Checkout)
	v1.POST("/webhooks/carrier", CarrierWebhook)
	v1.GET("/rates/:lane", ProxyRates)
	v1.GET("/catalog/:sku", CatalogItem)
	v1.GET("/stores/:id/geo", StoreGeo)
	v1.GET("/legacy/stores", LegacyStores)
}
