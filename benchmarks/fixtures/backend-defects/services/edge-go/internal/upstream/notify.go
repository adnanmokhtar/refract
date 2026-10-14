package upstream

import (
	"bytes"
	"encoding/json"
	"time"

	"github.com/hashicorp/go-retryablehttp"
)

var notifyClient = func() *retryablehttp.Client {
	c := retryablehttp.NewClient()
	c.RetryMax = 4
	c.RetryWaitMin = 200 * time.Millisecond
	c.HTTPClient.Timeout = 5 * time.Second
	return c
}()

// SendSMS asks the SMS provider to send one message (billed per request).
func SendSMS(to, text string) error {
	body, _ := json.Marshal(map[string]string{"to": to, "text": text})
	resp, err := notifyClient.Post("https://sms.example.test/v1/messages", "application/json", bytes.NewReader(body))
	if err != nil {
		return err
	}
	return resp.Body.Close()
}
