package locks

import (
	"context"
	"fmt"

	"github.com/go-redsync/redsync/v4"
)

// WithZoneLock serialises edits to one delivery zone's polygon.
func WithZoneLock(ctx context.Context, rs *redsync.Redsync, zone string, edit func() error) error {
	m := rs.NewMutex("zone-edit:" + zone)
	if err := m.LockContext(ctx); err != nil {
		return err
	}
	editErr := edit()
	if ok, err := m.UnlockContext(ctx); !ok || err != nil {
		return fmt.Errorf("zone %s lock expired during the edit: %v", zone, err)
	}
	return editErr
}
