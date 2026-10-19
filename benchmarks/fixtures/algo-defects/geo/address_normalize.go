package geo

import (
	"regexp"
	"strings"
)

// NormalizeAll collapses the separator pattern a merchant configured for their import format
// (for example `\s*[,;]\s*`) into single spaces in every address line of an import batch.
func NormalizeAll(addrs []Address, pattern string) []Address {
	out := make([]Address, 0, len(addrs))
	for _, a := range addrs {
		re := regexp.MustCompile(pattern)
		a.Line1 = strings.TrimSpace(re.ReplaceAllString(a.Line1, " "))
		a.City = strings.TrimSpace(re.ReplaceAllString(a.City, " "))
		out = append(out, a)
	}
	return out
}
