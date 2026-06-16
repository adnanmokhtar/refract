# Functional building blocks — coverage map

A reference taxonomy of the **functional building blocks** software is assembled from, grouped by concern, mapped to this repo's coverage. Companion to `_registry.md` (the authoritative technical-signal list). Business *verticals* (what the product IS) live in `../business-domains/`.

**Legend:** ✅ implemented domain pack · 🟡 cataloged (generate-on-detection, see `_registry.md`) · 🔵 covered by a track pack (`../packs/<track>/`) · 🟣 business-domain concern (`../business-domains/`).

## 1. Identity & Access
| Building block | Coverage |
|---|---|
| Authentication (login, sessions, MFA, reset) | ✅ `auth` |
| Authorization (RBAC/ABAC, permissions) | ✅ `auth` |
| SSO / OAuth / OIDC / SAML | ✅ `auth` |
| Multi-tenancy / org-account model | ✅ `multi-tenant` |
| Admin / back-office / impersonation | ✅ `admin` |
| Audit log / activity trail | ✅ `audit-log` |
| User & team management (invites, ownership) | 🟡 `user-team-management` |
| API keys / service accounts | ✅ within `public-api` · 🟡 `api-keys` (standalone) |

## 2. Money & Commerce
| Building block | Coverage |
|---|---|
| Payments (one-time, PSP) | ✅ `payment` |
| Subscriptions / recurring billing / dunning | ✅ `subscriptions` |
| Double-entry ledger / balances / wallet / credits | ✅ `ledger` |
| Invoicing / billing documents | 🟡 `invoicing` (← `document-generation` + `ledger`) |
| Tax / VAT / e-invoicing | 🟡 `tax` |
| Catalog / cart / checkout | 🟣 `ecommerce` |

## 3. Communication & Messaging
| Building block | Coverage |
|---|---|
| Notifications (email / SMS / push) | ✅ `notifications` |
| Real-time (websockets / SSE / presence) | ✅ `real-time` |
| Outbound webhooks | ✅ `webhook` |
| Comments / threads / mentions | 🟡 `comments` |
| Reviews / ratings | 🟡 `reviews-ratings` |
| In-app messaging / chat / inbox | 🟡 (← `real-time` + `moderation`) |

## 4. Data In & Out
| Building block | Coverage |
|---|---|
| File upload / storage | ✅ `file-upload` |
| Media processing (transcode / thumbnails) | ✅ `media-processing` |
| Streaming delivery (HLS/DASH, encrypted segments, decryption) | ✅ `streaming-delivery` |
| Bulk import / ingest | ✅ `import` |
| Reporting / export / dashboards | ✅ `reporting` |
| Search / autocomplete | ✅ `search` |
| Document / PDF generation | ✅ `document-generation` |
| Public API surface / SDK | ✅ `public-api` |
| Third-party integrations / connectors / sync | ✅ `integrations` |
| ETL / batch / backfill / CDC | ✅ `data-pipeline` |

## 5. Content & Domain Data
| Building block | Coverage |
|---|---|
| CRUD entity management | 🔵 backend track |
| Forms / form builder / submissions | ✅ `forms` |
| Workflow / approvals / state machines | ✅ `workflow` |
| Event sourcing / CQRS | ✅ `event-sourced` |
| Content management / CMS | 🟡 `cms` |
| Versioning / drafts / revision history | 🟡 `content-versioning` |
| Tagging / taxonomy / categorization | 🟡 `taxonomy` |
| Moderation / trust & safety | ✅ `moderation` |

## 6. Async & Processing
| Building block | Coverage |
|---|---|
| Background jobs / queues | ✅ `background-jobs` |
| Scheduling / calendar / availability / recurrence | ✅ `scheduling` |
| Event-driven / pub-sub topology | 🟡 `event-driven` |
| Workflow orchestration / sagas (Temporal) | 🟡 `workflow-orchestration` |

## 7. Intelligence & Insight
| Building block | Coverage |
|---|---|
| AI / LLM features | ✅ `ai` |
| Product analytics / telemetry | ✅ `analytics` |
| A/B testing / experimentation | ✅ `ab-testing` |
| Recommendations / personalization | 🟡 `recommendations` |
| MLOps (model lifecycle) | 🟡 `mlops` |

## 8. Operational & Platform
| Building block | Coverage |
|---|---|
| Feature flags | ✅ `feature-flags` |
| Rate limiting / quotas | ✅ `rate-limiting` |
| Caching | ✅ `caching` |
| Configuration / settings / preferences | ✅ `settings` |
| Compliance (HIPAA/GDPR/PCI) | ✅ `compliance` |
| Internationalization / localization | ✅ `i18n` |
| Observability (logs / metrics / traces) | 🔵 observability track |
| GitOps / IaC reconciliation | 🟡 `gitops` |

## 9. Lifecycle & Engagement
| Building block | Coverage |
|---|---|
| Onboarding / setup wizards | 🟡 `onboarding` |
| Activity feed / timeline | 🟡 `activity-feed` |
| Gamification (points / badges / streaks) | 🟡 `gamification` |
| Referrals / affiliate | 🟣 `affiliate` |

---

## How to read this

- **✅ (34 packs)** — a full specialist pack ships today: a cite-or-halt discipline rule, a deep ai-pattern with real code, a reviewer agent with a BLOCKER taxonomy, and a diagnostic command. Listed in `_registry.md` (implemented).
- **🟡 (cataloged)** — reserved keys; `/setup-project` Phase 4.5 generates a pack on first detection and saves it back for reuse. Listed in `_registry.md` (cataloged).
- **🔵 (track pack)** — handled by a practitioner track under `../packs/` (backend, frontend, observability, …), not as a cross-cutting signal.
- **🟣 (business domain)** — a product vertical under `../business-domains/`, not a technical signal.

## Maintenance

When a 🟡 is promoted to ✅: build the 5-file pack under `templates/domains/<key>/`, move its `_registry.md` row from the cataloged table to the implemented table, and update this file's marker. Keep this map in sync with `_registry.md` — `_registry.md` is authoritative for the implemented/cataloged split.
