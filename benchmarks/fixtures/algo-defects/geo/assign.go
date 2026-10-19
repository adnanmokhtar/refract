package geo

// AssignByZone gives each pending order in a courier's zone to that courier, up to the courier's
// capacity. Runs on every dispatch tick over all on-shift couriers and all pending orders in the region.
func AssignByZone(couriers []Courier, orders []PendingOrder, capacity int) map[string][]string {
	assigned := make(map[string][]string, len(couriers))
	for _, c := range couriers {
		load := c.Load
		for i := range orders {
			o := &orders[i]
			if c.ZoneID == o.ZoneID && o.CourierID == "" && load < capacity {
				o.CourierID = c.ID
				assigned[c.ID] = append(assigned[c.ID], o.ID)
				load++
			}
		}
	}
	return assigned
}
