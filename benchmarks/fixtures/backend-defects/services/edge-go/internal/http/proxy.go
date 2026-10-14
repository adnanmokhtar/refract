package edgehttp

import (
	"context"
	"io"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/lumen/edge-go/internal/upstream"
)

// ProxyRates returns the carrier's live shipping rates for a lane.
func ProxyRates(c *gin.Context) {
	upstream.WriteRates(c.Writer, c.Param("lane"))
}

// CatalogItem returns a catalog item from the PIM.
func CatalogItem(c *gin.Context) {
	item, err := upstream.FetchCatalogItem(c.Request.Context(), c.Param("sku"))
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": gin.H{"code": "UPSTREAM_PIM", "message": "catalog unavailable"}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": item})
}

// StoreGeo returns the store's coordinates from the geo provider.
func StoreGeo(c *gin.Context) {
	body, err := upstream.StoreGeo(c.Request.Context(), c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": gin.H{"code": "UPSTREAM_GEO", "message": "geo unavailable"}})
		return
	}
	c.Data(http.StatusOK, "application/json", body)
}

var apiClient = &http.Client{Timeout: 10 * time.Second}

func placeOrder(ctx context.Context, cartID, payment string) (string, error) {
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, "http://api:3000/v1/orders", nil)
	req.Header.Set("X-Cart", cartID+":"+payment)
	resp, err := apiClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	return string(b), nil
}
