---
description: Replay a WhatsApp webhook fixture against the local (or staging) API, with valid HMAC.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /simulate-webhook

Purpose: reproduce a real-looking WhatsApp message delivery locally. Used during development, debugging, and manual QA.

## Premise

Real signals only. Cite the actual fixture path, computed HMAC, target URL, response status + body, and any new `messages` rows by id — never narrate a delivery you didn't POST. Read before writing: confirm the fixture exists at `test/fixtures/whatsapp/<name>.json` and `WHATSAPP_APP_SECRET` is set BEFORE signing. `phone_number_id` must resolve to a seeded tenant; if not, halt with the seeding hint.

## Mechanical halt

Cite-or-halt: every run prints the fixture path, signature header value (truncated), response status, and the diff in `messages` (new ids or "no insert"). Refuse to run against any host that isn't `localhost` or an explicit `--target` non-prod URL. `--tamper` must report the actual 401 (or whatever the server returned) — never assume.

## What it does

1. Loads a fixture JSON from `test/fixtures/whatsapp/` (default: `text-message.json`).
2. Computes `HMAC-SHA256(body, WHATSAPP_APP_SECRET)` — from `.env`.
3. POSTs to `http://localhost:3000/webhooks/whatsapp` with `X-Hub-Signature-256: sha256=<hex>`, `Content-Type: application/json`.
4. Prints response status + body + any new rows in `messages`.

## Fixtures available

- `text-message.json` — vanilla text.
- `text-message-arabic.json` — Egyptian Arabic body.
- `text-message-out-of-stock-query.json` — asks about a product that's out of stock.
- `duplicate-message.json` — same `wa_message_id` as another fixture (tests idempotency).
- `unsupported-type.json` — voice note (must log `unsupported_message_type` and 200).

Add new fixtures whenever you find a real-world payload worth replaying.

## Usage

```bash
.claude/skills/simulate-webhook.sh                                  # default fixture, localhost
.claude/skills/simulate-webhook.sh text-message-arabic.json         # different fixture
.claude/skills/simulate-webhook.sh -u https://staging.example.com   # different target
```

Or slash: `/simulate-webhook text-message-arabic.json`.

## Tampered-body test

`/simulate-webhook --tamper` flips one byte of the body before signing → expected 401 (validates the HMAC guard).

## Must-haves in the fixture

Each fixture is a full Meta payload:

```json
{
  "object": "whatsapp_business_account",
  "entry": [{
    "id": "<WABA_ID>",
    "changes": [{
      "value": {
        "messaging_product": "whatsapp",
        "metadata": { "display_phone_number": "...", "phone_number_id": "<TEST_PHONE_ID>" },
        "contacts": [{ "profile": { "name": "Ahmed" }, "wa_id": "2010..." }],
        "messages": [{ "from": "2010...", "id": "wamid.abc", "timestamp": "1714...", "type": "text", "text": { "body": "عايز أعرف سعر الجاكيت" } }]
      },
      "field": "messages"
    }]
  }]
}
```

`phone_number_id` must match a seeded tenant. If not, the command prints a hint to seed one.
