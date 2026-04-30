---
description: Send a notification through every wired channel to a test recipient with full headers + delivery report. Provider-aware (SES / Twilio / FCM / OneSignal / WhatsApp Cloud).
---

# /test-notification

Purpose: verify every channel actually delivers — locally or to staging — without production user spam.

## Premise

Real signals only. Cite the actual provider message id (`MessageId`, Twilio `sid`, FCM message name, `wamid.*`), latency, terminal status from the provider's own status callback / API. Read before writing: confirm `.env.test` recipients are set + sandbox/test-mode is active BEFORE any send. Never mark a channel `OK` from API-acceptance alone — wait for the terminal delivery event (or `dryRun` for FCM) and cite it.

## Mechanical halt

Cite-or-halt: every channel row must carry the provider's id and a real status string. If the status webhook / poll times out, mark `UNKNOWN` with the timeout duration — never `delivered` by assumption. Refuse to send if `--to` resolves to anything but the configured test recipients.

## What it does

1. Loads test recipient from `.env.test` (or `--to`):
   - `TEST_EMAIL`, `TEST_PHONE`, `TEST_FCM_TOKEN`, `TEST_WHATSAPP_NUMBER`.
2. For each registered channel:
   - Renders the chosen template with seeded data.
   - Calls the channel adapter's `send()` directly (bypass preferences for test recipient — separate code path or `force: true` flag).
   - Captures provider response: message ID, latency, status.
3. Polls provider status webhooks (or sandbox API) for terminal state: delivered / bounced / failed.
4. Prints a delivery report.

## Usage

```bash
.claude/skills/test-notification.sh                                 # default template across all channels
.claude/skills/test-notification.sh --template=order-confirmation   # one template
.claude/skills/test-notification.sh --channel=email                 # one channel
.claude/skills/test-notification.sh --to=eng@example.com --channel=email
.claude/skills/test-notification.sh --provider=ses --debug          # full SMTP trace
```

## Per-provider details

### Email — Amazon SES

- Sandbox mode: only sends to verified addresses. Verify `TEST_EMAIL` first.
- `aws ses send-email --raw-message ...` returns `MessageId`.
- Status via SNS topic → SQS → poll for delivery / bounce / complaint event.
- Headers to inspect: `Return-Path`, `DKIM-Signature`, `Authentication-Results`, `List-Unsubscribe`.

```bash
aws ses send-raw-email --raw-message file://test-email.eml
# Then watch the SNS-bound SQS queue for delivery event:
aws sqs receive-message --queue-url $SES_EVENTS_QUEUE --wait-time-seconds 20
```

### Email — Mailgun / SendGrid

- Mailgun: `POST /v3/<domain>/messages` returns `id`. Status via webhook OR `GET /v3/<domain>/events?message-id=...`.
- SendGrid: `POST /v3/mail/send` returns `X-Message-Id` header. Status via `GET /v3/messages?query=msg_id="..."` (Pro plan).

### SMS — Twilio

- Test credentials: `AC*` + token from Console → won't actually send, returns canned response.
- Real send: use a magic test number (`+15005550006` triggers configurable response).
- `client.messages.create({ to, from, body })` returns `sid`. Status via `client.messages(sid).fetch()` or status callback URL.
- Inspect: `status` (queued → sent → delivered), `errorCode`, `errorMessage`.

```bash
twilio api:core:messages:create --from $FROM --to $TEST_PHONE --body "Test"
twilio api:core:messages:fetch --sid SMxxxxx
```

### Push — Firebase Cloud Messaging

- `admin.messaging().send(message)` returns message name (no delivery confirmation — FCM is fire-and-forget unless using `data` payloads with app-side ack).
- For delivery insight: enable BigQuery export OR use `dryRun: true` to validate token + payload without sending.

```ts
await admin.messaging().send({
  token: TEST_FCM_TOKEN,
  notification: { title: 'Test', body: 'Test push' },
  data: { type: 'test', correlationId },
}, /* dryRun */ true);   // validates, doesn't deliver
```

### Push — OneSignal

- `POST /notifications` with `include_player_ids: [TEST_PLAYER_ID]` returns notification id.
- `GET /notifications/<id>?app_id=...` returns delivery / opened counts.

### WhatsApp Cloud API

- Use the test phone number provisioned in Meta Developer Portal (free tier: 5 recipients).
- `POST /v17.0/<phone-number-id>/messages` with template message (free-form requires user-initiated 24h window).
- Returns `messages[0].id`; status via webhook (`statuses[]` array — sent / delivered / read / failed).

```bash
curl -X POST "https://graph.facebook.com/v17.0/$PNID/messages" \
  -H "Authorization: Bearer $WA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "messaging_product": "whatsapp",
    "to": "'$TEST_WHATSAPP_NUMBER'",
    "type": "template",
    "template": { "name": "hello_world", "language": { "code": "en_US" } }
  }'
```

## Output report

```
/test-notification — template=order-confirmation

Channel: email (SES)
  Provider message ID: 010f018e3ab...
  Latency to API:      184 ms
  Status:              delivered (after 4.2s)
  DKIM:                pass
  SPF:                 pass
  DMARC:               pass
  Unsubscribe header:  present (mailto + One-Click HTTPS)
  Body sample:         "Hi Sara, your order #12345 ..."
  → OK

Channel: sms (Twilio)
  SID:                 SMabcd1234...
  Latency to API:      342 ms
  Status:              delivered (after 2.1s)
  Segments:            1 (160 chars)
  Body sample:         "Your order #12345 has shipped. Track: example.com/o/12345"
  → OK

Channel: push (FCM)
  Validation (dryRun): success
  Token age:           4d (fresh)
  Payload size:        211 bytes (limit: 4096)
  PII scan:            clean (no email/phone/address in body)
  → OK

Channel: whatsapp (Cloud API)
  Message ID:          wamid.HBg...
  Status:              sent → delivered (1.8s) → read (12s)
  Template:            order_shipped (approved)
  → OK

Summary: 4/4 channels delivered.
```

## When to run

- After any change to a channel adapter or template.
- Before enabling a new template in production.
- After rotating provider credentials.
- After updating sender domain DNS (SPF/DKIM/DMARC propagation check).
- Daily smoke from CI on staging.

## Failure modes the command surfaces

- **DKIM fail** — DNS propagation or wrong key. Fix DNS or rotate key.
- **Bounce immediately** — recipient on suppression list. `--reset-suppression` to clear.
- **Twilio error 21610** — recipient texted STOP. Re-opt-in flow required.
- **FCM `UNREGISTERED`** — token expired. App needs to refresh.
- **WhatsApp `131047`** — outside 24h customer window, must use template message.
- **No SMS segment** — body had unsupported unicode, silently chunked into 7-bit pieces.
