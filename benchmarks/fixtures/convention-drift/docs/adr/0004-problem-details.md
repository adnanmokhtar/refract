# ADR-0004 — Errors are RFC 9457 problem details

- Status: Accepted
- Date: 2025-11-03

## Context

Clients parse three error shapes today: `{ error }`, `{ message, statusCode }` and the proxy's HTML.

## Decision

Every error response from `apps/api` is `application/problem+json` (RFC 9457), written by
`ProblemDetailsFilter`. Controllers throw an `HttpException` subclass; they never build an error
body or set an error status themselves. Endpoints are served under `/api/v2`.

## Confirmation

`apps/api/.spectral.yaml` rule `acme-problem-json` at error on the generated OpenAPI document.
