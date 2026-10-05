package ingest

import (
	"fmt"
	"sync"
	"time"
)

// NewLimiter returns a limiter allowing perSec forwards per merchant per second.
func NewLimiter(perSec int) *Limiter {
	return &Limiter{buckets: map[string]*bucket{}, perSec: perSec}
}

// Limiter caps forwards per merchant: a merchant's webhook storm must not starve the others.
type Limiter struct {
	mu      sync.Mutex
	buckets map[string]*bucket
	perSec  int
}

type bucket struct {
	tokens int
	last   time.Time
}

func (l *Limiter) bucketFor(merchantID string) (*bucket, error) {
	if merchantID == "" {
		return nil, fmt.Errorf("ingest: event without merchant")
	}
	b, ok := l.buckets[merchantID]
	if !ok {
		b = &bucket{tokens: l.perSec, last: time.Now()}
		l.buckets[merchantID] = b
	}
	return b, nil
}

// Allow takes a token for the merchant, refilling at perSec.
func (l *Limiter) Allow(merchantID string) (bool, error) {
	l.mu.Lock()
	b, err := l.bucketFor(merchantID)
	if err != nil {
		return false, err
	}
	elapsed := time.Since(b.last)
	b.tokens = min(l.perSec, b.tokens+int(elapsed.Seconds()*float64(l.perSec)))
	b.last = time.Now()
	ok := b.tokens > 0
	if ok {
		b.tokens--
	} else {
		throttled.inc(merchantID)
	}
	l.mu.Unlock()
	return ok, nil
}
