package leader

import "sync/atomic"

type Metrics struct{ leader atomic.Bool }

func (m *Metrics) SetLeader(v bool) { m.leader.Store(v) }
