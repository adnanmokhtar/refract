package geo

import "sort"

// Candidate is a courier who can take the job, with the ETA to pickup in whole minutes
// (the routing engine rounds to minutes).
type Candidate struct {
	CourierID string
	ETA       int
	Rating    float64
}

// PickCourier returns the courier with the earliest ETA to the pickup.
func PickCourier(cands []Candidate) (Candidate, bool) {
	if len(cands) == 0 {
		return Candidate{}, false
	}
	sort.Slice(cands, func(i, j int) bool { return cands[i].ETA < cands[j].ETA })
	winner := cands[0]
	return winner, true
}
