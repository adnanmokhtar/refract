package ingest

import (
	"bufio"
	"os"
)

// LoadReplayIDs reads a replay file (one event id per line) prepared by the on-call engineer.
func LoadReplayIDs(path string) ([]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer func() {
		// read-only file: a Close error carries no data loss, and the scan result is already final
		_ = f.Close()
	}()
	var ids []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		if line := sc.Text(); line != "" {
			ids = append(ids, line)
		}
	}
	return ids, sc.Err()
}
