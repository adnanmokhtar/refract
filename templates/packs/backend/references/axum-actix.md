# Rust web servers reference — axum and actix-web

> **Framework**: axum 0.8.x (0.8.9 is the newest stable on crates.io, 2026-04-14) with `tower-http` 0.7.x (0.7.1) • actix-web 4.x (4.16.0, 2026-10-12) — crates.io, read 2026-10-14
> **Official docs**: https://docs.rs/axum • https://docs.rs/actix-web • https://docs.rs/tower-http
> **Version-specific gotchas**: axum 0.8 changed path captures to `/{id}` and `/{*rest}` and **panics** at router build on the 0.7 `/:id` form; both frameworks answer extractor failures in **plain text**; a handler panic is not a JSON 500 unless something catches it.
> **Substitution markers**: Replace `<Router>` / `<handler>` / `ApiError` with the project's actual names from `_extracted-idioms.md`.

Every row says how it was established: **read** = the published source on 2026-10-14 — axum and axum-core at tag `axum-v0.8.9`, `tower-http` at tag `tower-http-0.7.1`, the actix-web 4.16.0 crate from crates.io; **docs** = serde.rs, read 2026-10-14. No Rust toolchain ran here: a row that depends on runtime behaviour beyond the source is marked **not run** and needs the proof named before a detector asserts it. Read the installed versions from `Cargo.lock` first.

## Routing (axum)

| Code | axum 0.8.9 (read) |
|---|---|
| `.route("/users/:id", get(h))` | **panic at router build**: "Path segments must not start with `:`" (the 0.8 changelog: the old syntax panics "to avoid silent change in behavior"); `Router::without_v07_checks()` turns the check off for a literal `:` segment |
| `.route("/files/*rest", …)` | panic: use `/{*rest}` |
| `.route("/users/{id}", …)` | correct |
| `Option<Path<T>>` | no longer swallows every error (0.8): many malformed paths are now rejected |
| tuple `Path<(A, B)>` | the parameter count must match exactly (0.8) |

The panic happens when the router is built, so a router test that only builds the app catches it (http-contract-scan §11, V346 / V357).

## Extractor rejections — status and content type

| Failure | axum 0.8.9 `Json<T>` (read) | actix-web 4.16.0 `web::Json<T>` (read) |
|---|---|---|
| missing or wrong `Content-Type` | **415** `Expected request with Content-Type: application/json` | **400** (`content_type_required` defaults to true; `JsonPayloadError::ContentType` maps to 400) |
| malformed JSON | 400 `Failed to parse the request body as JSON` | 400 |
| valid JSON, wrong shape or type | **422** `Failed to deserialize the JSON body into the target type` | 400 |
| body over the limit | 413 (default limit **2 MB**) | 413 (`DEFAULT_LIMIT` 2,097,152 bytes) |
| body | `text/plain` — the rejection is `(status, text)` | `text/plain` — `ResponseError`'s default `error_response` writes the error's `Display` text |

Both answer outside a JSON envelope unless the project wraps the extractor: axum `#[derive(FromRequest)] #[from_request(via(axum::Json), rejection(ApiError))]` or `axum_extra::extract::WithRejection<Json<T>, ApiError>`; actix `web::JsonConfig::default().error_handler(|err, req| …)`. The same request answering 415 on one service and 400 on another is a contract drift (http-contract-scan §3). Owner: edge-error-scan §6 (V345).

## Body limits (axum)

`DefaultBodyLimit` (2 MB) applies to `Bytes` and the extractors built on it — `String`, `Json`, `Form` — **not** to an extractor that reads the raw `Body` stream (`poll_frame`), which is unlimited unless wrapped (`http_body_util::Limited`) or a global `tower_http::limit::RequestBodyLimitLayer` is set (read, axum-core doc comment). Limits as capacity and DoS are performance's and security's; the 413 that leaves the envelope is edge-error-scan §6.

## Errors and panics

| Case | Behaviour |
|---|---|
| actix: a custom error type with `impl ResponseError` and no `status_code` | **500** by default, body = the `Display` text, `text/plain` (read) — override `status_code` and `error_response` per variant |
| axum: a handler returns `Result<T, E>` | `E: IntoResponse` decides status and body — one `impl IntoResponse for ApiError` is the mapping point |
| axum: a handler panics with `tower_http::catch_panic::CatchPanicLayer` | 500 `text/plain; charset=utf-8` (read, `tower-http` 0.7.1); `CatchPanicLayer::custom(handler)` builds a JSON body |
| axum: a handler panics with no `CatchPanicLayer` | the request ends without a mapped response — **not run**; prove it with a panicking test route (edge-error-scan §4, V345) |
| actix: a handler panics | **not run**; same proof |

Map domain and DB errors (`sqlx::Error::RowNotFound`, a unique violation's SQLSTATE `23505`, Diesel `NotFound`) in the one `IntoResponse` / `ResponseError` impl; a `?` that converts them into a catch-all variant answers 500 (edge-error-scan §1–§2, V330).

## Deserialization defaults (serde)

- Unknown JSON fields are **ignored** unless the type carries `#[serde(deny_unknown_fields)]` (docs; the attribute does not combine with `flatten`). The silent drop is validation-boundary-scan §6 (V343).
- A missing field with `#[serde(default)]` takes `Default::default()` — `0`, `false`, `""` — indistinguishable from a client that sent it (validation-boundary-scan §5).
- Money as `f64` and a 64-bit id serialized as a JSON number reach JavaScript clients rounded past 2^53: use a decimal type serialized as a string and `#[serde(with = "…string")]` ids (wire-format-scan §1–§2).

## Which detector owns what

| Concern | Owner |
|---|---|
| 0.7 → 0.8 path syntax, `Option<Path>` and tuple changes | http-contract-scan §11 |
| plain-text rejections, 415 vs 400 vs 422 | edge-error-scan §6; cross-service drift http-contract-scan §3 |
| panics, `CatchPanicLayer` | edge-error-scan §4 |
| `ResponseError` default 500, unmapped DB errors | edge-error-scan §1–§2 |
| unknown fields, defaults | validation-boundary-scan §5–§6 |
| `f64` money, 64-bit ids | wire-format-scan §1–§2 |

Sources: axum `axum/src/extract/rejection.rs`, `axum/src/routing/{mod.rs,path_router.rs}`, `axum/CHANGELOG.md` (0.8.0), `axum-core/src/{macros.rs,extract/default_body_limit.rs}` at `axum-v0.8.9`; `tower-http/src/catch_panic.rs` at `tower-http-0.7.1`; actix-web 4.16.0 `src/error/{response_error.rs,mod.rs}` and `src/types/json.rs` from the crates.io archive; serde.rs container and field attributes — all fetched 2026-10-14. The research rows BF-RS-01..05 (research-backend § 1.12) were `[K]` for the path panic, the rejection statuses and the panic behaviour; this file reads the first two from source and leaves the third not run. Paraphrased; no text reproduced beyond identifiers and error strings.
