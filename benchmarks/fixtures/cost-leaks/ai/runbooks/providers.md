# Runbook — paid providers

Every third party Quaywise pays per use, how to reach its console, and what to do when it fails.
Keys live in the `quaywise-secrets` Secret; rotate them with the platform on-call.

## Model gateway (tracking assistant, claim triage)

- Endpoint: `LLM_GATEWAY_URL`; model alias `qw-assist-large` (switch models in the gateway, not in code).
- Keys: one per environment, rotated every 90 days in the gateway console under **API keys**.
- The account is on usage tier 4 since 2026-06 (raised for the claim-triage launch).
- A 429 from the gateway fails the request; the tracking page shows "try again in a minute".

## Twilio (SMS)

- Messaging service `quaywise-status` with geo permissions limited to the EU and the UK.
- Delivery receipts arrive at `/webhooks/twilio/status`; failed deliveries are visible per merchant.
- A 21610 (recipient opted out) is final; do not retry.

## ParcelNet (labels, tracking, rate cards)

- REST API keys per environment; the sandbox is `sandbox.parcelnet.example`.
- Label jobs render asynchronously; tracking and rate cards are read on demand.
- Push webhooks for tracking scans are available (`POST /v1/subscriptions`) and not enabled yet.

## Addressly (address verification) and MapGrid (geocoding)

- Addressly: one key, verify endpoint only. MapGrid: one key per environment.
- Both invoice monthly in arrears against the company card; invoices go to accounts@quaywise.example.

## Paging

The latency budget alert for the tracking API pages the dispatch on-call; provider outages page
the platform on-call. Neither is a reason to raise a provider's limits without the platform lead.
