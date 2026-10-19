package geo

import "sort"

// Scored is a store scored for a shopper's home feed.
type Scored struct {
	ID    string
	Score float64
}

// RankStores orders stores by score, highest first; equal scores fall back to the store id so the
// feed is identical on every refresh.
func RankStores(rows []Scored) []Scored {
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].Score != rows[j].Score {
			return rows[i].Score > rows[j].Score
		}
		return rows[i].ID < rows[j].ID
	})
	return rows
}
