# ADR-0005 — Twilio for recipient SMS

Status: accepted · 2026-02-20 · deciders: dispatch lead, platform lead

## Context

Recipients get up to four status messages per parcel. We need EU and UK delivery, delivery receipts
and an opt-out flow that satisfies the carriers' notification rules.

## Decision

Twilio Programmable Messaging through one Messaging Service (`quaywise-status`), with geo
permissions limited to the EU and the UK. Sending goes through `SmsService` only.

## Consequences

- One Twilio project per environment; the dev project sends to verified numbers only.
- The monthly SMS spend is reviewed in the Twilio console by the dispatch lead.
- Moving providers means re-registering sender IDs in each country (about four weeks).
