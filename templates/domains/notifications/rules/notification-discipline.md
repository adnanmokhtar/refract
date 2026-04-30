---
name: notification-discipline
description: Notification discipline
kind: rule
---

# Notification discipline

## Hard rule

Every notification MUST be classified at code-level into exactly one of `transactional` / `account` / `marketing` / `operational`, MUST flow through `NotificationService.send()` (preferences + suppression checked before provider call), and MUST carry an idempotency key. Marketing MUST ship with a one-click unsubscribe + `List-Unsubscribe` headers. Mis-classifying marketing as transactional to bypass opt-out is FORBIDDEN.

User-visible AND legally regulated. Every send obeys the rules below.

## Categories (mandatory taxonomy)

Every notification is classified at code-level into ONE of:

- **transactional** — user action requires response: receipt, password reset, security alert, OTP. CANNOT be opted out (legal + UX).
- **account** — account state change: subscription renewal, payment failure, plan change. Limited opt-out (warn the user).
- **marketing** — promotional, recommendation, re-engagement. MUST be opt-in (GDPR / EU) or opt-out (US), with one-click unsubscribe.
- **operational** — system-state info to admins (digest reports, weekly summary). Per-user opt-out.

Mis-classifying a marketing message as transactional to bypass opt-out is a compliance violation, not a workaround.

## Preferences (must be checked on every send)

- `notification_preferences` table indexed by `(user_id, category, channel)` → boolean.
- `NotificationService.send()` consults preferences BEFORE provider call. Skipped sends logged with reason.
- Transactional preferences exist but are read-only in UI (cannot disable).
- Marketing requires explicit `marketing_consent_at IS NOT NULL`. `unsubscribed_at IS NULL`.
- Channel-level revoke (e.g. SMS STOP, push permission revoked at OS level) is automatic — provider webhooks update the table.

## Sender separation (deliverability)

- Transactional from `mail.<domain>` / `notifications.<domain>` — protected reputation, separate IP pool.
- Marketing from `news.<domain>` / `hello.<domain>` — different ESP if possible (Mailchimp / Customer.io / Braze).
- SPF + DKIM + DMARC configured per sending domain; DMARC at minimum `quarantine`, ideally `reject`.
- Reverse DNS matches HELO.
- Bounces (hard) go to suppression list within minutes; suppression checked on every send.

## Rate limits

- Per-user, per-channel, per-24h cap. Defaults: marketing 5, transactional 20, push 30, in-app unlimited.
- Per-tenant cap to defuse runaway loops (broken job sending 1M emails to one user).
- Provider TPS respected via queue `limiter` — never a raw concurrency = N worker pool.
- Burst protection on triggered campaigns (buy now → email + SMS + push) — debounce within 60s.

## Payload safety

- Push notifications: title + body contain ZERO PII beyond first name. No order #, no amount, no address. Tap-through to authenticated app.
- SMS: body reveals nothing actionable to a stranger holding the phone (no OTP context like "your bank login code").
- Email subject + preheader treated as visible to anyone glancing at the inbox.
- Localized; fail-closed if locale not configured rather than English fallback for non-English users (worse UX than no notification).

## Failover (critical only)

- Critical (`security_alert`, `password_reset`, `mfa_otp`): explicit fallback chain — email → SMS if email bounces within 30s, OR send both simultaneously if user opted in.
- Non-critical NEVER auto-fallback. Marketing-email-fall-to-SMS = TCPA violation in US.
- Failover paths defined per-category, not per-call.

## Reliability

- Send is enqueued, NOT awaited from a controller. Provider 5xx must not 500 the user request.
- Worker retries: transient (5xx, 429, network) with exponential backoff, max 5 attempts. Permanent (4xx bad recipient) → suppress + DLQ.
- Idempotency: provider message ID stored on the notification row; idempotency key passed to provider (SES `MessageDeduplicationId`, Twilio `IdempotencyKey`) so retries don't double-send.
- Hard bounces → mark recipient unmailable; do not retry, do not auto-replay.

## Unsubscribe (compliance)

- Every marketing email contains:
  - Visible unsubscribe link in footer.
  - `List-Unsubscribe: <https://...>, <mailto:...>` header.
  - `List-Unsubscribe-Post: List-Unsubscribe=One-Click` header (RFC 8058) — Gmail/Yahoo will downrank you without it.
- Unsubscribe processes within 10 days max (CAN-SPAM); ideally instant.
- SMS: STOP / UNSUBSCRIBE / CANCEL / END / QUIT keyword handler wired; auto-opt-out on receive; one-time confirmation reply allowed.
- Push: in-app preference toggle + OS-level permission state honored.

## Observability

- Every notification recorded with full lifecycle: sent → delivered → opened → clicked → bounced / complained / unsubscribed.
- Provider webhooks ingested (SES SNS, Twilio status, Firebase delivery).
- Metrics per template: send rate, delivery rate, bounce rate, complaint rate, unsubscribe rate, click rate.
- Alerts:
  - complaint rate > 0.1% (SES throttles / suspends at 0.5%);
  - bounce rate > 5%;
  - unsubscribe rate > 2× baseline;
  - delivery rate < 95%.

## Forbidden

- Direct provider call bypassing `NotificationService`.
- PII in push body / SMS body.
- Marketing on transactional sender domain.
- Marketing template without unsubscribe link + `List-Unsubscribe` headers.
- `await provider.send` from a controller.
- Suppression list not consulted before send.
- "Transactional" classification on marketing content.
- Auto-fallback marketing across channels.
- Send loops without rate limit.

## Enforcement

- `/notification-audit` command — greps for direct provider calls bypassing `NotificationService`, marketing templates without `List-Unsubscribe` headers, push/SMS payloads matching PII regexes.
- CI lint MUST reject any import of provider SDKs (`@sendgrid/mail`, `twilio`, `firebase-admin`) outside the canonical `notifications/providers/` directory.
- DMARC + SPF + DKIM checked at deploy time per sending domain — missing configuration fails the deploy.
- Provider webhook ingestion (bounce, complaint, unsubscribe) MUST update `notification_preferences` automatically; missing webhook handler fails the audit.
- TODO: `scripts/validate-notification-classification.sh` to require every `send(...)` call site to specify `category:` and assert it matches the template's declared class.
