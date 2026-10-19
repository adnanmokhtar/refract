package geo

import (
	"cmp"
	"slices"
)

// Row is one courier's weekly points on the leaderboard.
type Row struct {
	CourierID string
	Name      string
	Points    int
}

// LeaderboardPage returns one page of the weekly courier leaderboard (most points first).
// The app pages through it with ?offset=&size=.
func LeaderboardPage(rows []Row, off, size int) []Row {
	slices.SortFunc(rows, func(a, b Row) int { return cmp.Compare(b.Points, a.Points) })
	if off >= len(rows) {
		return nil
	}
	end := min(off+size, len(rows))
	return rows[off:end]
}
