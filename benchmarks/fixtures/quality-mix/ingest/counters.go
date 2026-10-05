package ingest

// deliveriesByMerchant feeds the per-merchant delivery count on the ops dashboard.
// net/http serves each request on its own goroutine.
var deliveriesByMerchant = map[string]int{}

func recordDelivery(merchantID string) {
	deliveriesByMerchant[merchantID]++
}

// DeliveryCount is read by the /debug/deliveries endpoint.
func DeliveryCount(merchantID string) int {
	return deliveriesByMerchant[merchantID]
}
