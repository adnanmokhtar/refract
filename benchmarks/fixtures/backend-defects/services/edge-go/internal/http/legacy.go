package edgehttp

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// LegacyStores is the v0 store list, deprecated on 2026-01-01 and retired on 2026-12-31.
func LegacyStores(c *gin.Context) {
	c.Header("Deprecation", "@1767225600")
	c.Header("Sunset", "Thu, 31 Dec 2026 23:59:59 GMT")
	c.Header("Link", `</v1/stores>; rel="successor-version"`)
	c.JSON(http.StatusOK, gin.H{"data": []gin.H{}})
}
