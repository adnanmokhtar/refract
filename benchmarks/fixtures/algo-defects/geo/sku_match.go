package geo

import "regexp"

// skuRe matches the warehouse SKU format: letter groups (optionally dash-joined) then three digits.
var skuRe = regexp.MustCompile(`^([A-Z]+-?)+[0-9]{3}$`)

// ValidSKUs keeps the scanned codes that look like warehouse SKUs.
func ValidSKUs(scanned []string) []string {
	out := make([]string, 0, len(scanned))
	for _, s := range scanned {
		if skuRe.MatchString(s) {
			out = append(out, s)
		}
	}
	return out
}
