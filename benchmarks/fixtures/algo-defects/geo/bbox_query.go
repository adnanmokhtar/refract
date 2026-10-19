package geo

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

// BBox is a map viewport in degrees.
type BBox struct {
	West, East, South, North float64
}

const couriersInViewSQL = `
SELECT courier_id, lat, lng
  FROM courier_positions
 WHERE lng BETWEEN $1 AND $2 AND lat BETWEEN $3 AND $4
   AND seen_at > now() - interval '2 minutes'`

// CourierPosition is the last known position of an on-shift courier.
type CourierPosition struct {
	CourierID string
	Lat, Lng  float64
}

// CouriersInView feeds the dispatcher's live map for the viewport the operator is looking at.
func CouriersInView(ctx context.Context, db *pgxpool.Pool, b BBox) ([]CourierPosition, error) {
	rows, err := db.Query(ctx, couriersInViewSQL, b.West, b.East, b.South, b.North)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []CourierPosition
	for rows.Next() {
		var p CourierPosition
		if err := rows.Scan(&p.CourierID, &p.Lat, &p.Lng); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}
