// Package geo is the courier routing and dispatch core linked into the dispatcher.
package geo

import "time"

// Address is a delivery address as captured at checkout.
type Address struct {
	ID    string
	Line1 string
	City  string
	Lat   float64
	Lng   float64
}

// Courier is an on-shift courier.
type Courier struct {
	ID     string
	ZoneID string
	Load   int
}

// PendingOrder is a paid order waiting for a courier.
type PendingOrder struct {
	ID        string
	ZoneID    string
	CourierID string
	ReadyAt   time.Time
}

// Zone is a merchant-drawn delivery zone; merchants nest zones (suburb → street block → building).
type Zone struct {
	Code     string
	Children []*Zone
}
