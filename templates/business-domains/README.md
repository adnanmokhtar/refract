# Business domains catalog

A project's STACK answers "what tech is in use?" — its DOMAIN answers "what business is it actually running?" Both matter; this catalog covers the second.

`/setup-project` consults this catalog after stack detection to decide:
- Which canonical entities the project should have (Order/Cart/Refund for ecommerce; Course/Enrollment/Quiz for LMS).
- Which core flows the team should plan for (checkout, refund, dispute for ecommerce; lesson-completion, certification for LMS).
- Which compliance regimes apply (PCI-DSS for ecommerce; FERPA for LMS; HIPAA for healthcare; PCI + SOX for fintech).
- Which stakeholder vocabulary to use (merchant/customer for ecommerce; instructor/student for LMS).
- Which anti-patterns specific to that domain to flag.

## Catalog (15 domains as of 2026-04)

| Domain | Description | Common stacks |
|---|---|---|
| `ecommerce` | Sell physical/digital goods. Cart, checkout, orders, refunds, fulfillment. | NestJS+Postgres / Laravel+MySQL / Shopify-app / Medusa |
| `marketplace` | Multi-seller ecommerce — sellers + buyers + commission. | Same as ecommerce + seller dashboards |
| `lms` | Learning Management — courses, enrollments, lessons, quizzes, certificates. | Laravel + Vue / Next.js / Moodle plugins |
| `booking` | Time-slot reservations — gyms, salons, doctors, restaurants, services. | Calendars-heavy, often React-Native + API |
| `fintech` | Money movement — accounts, ledgers, transactions, payouts, KYC. | Java / Go / Postgres + ledger lib |
| `insurance` | Policies, claims, premiums, underwriting, beneficiaries. | Heavy domain modeling, often Java / .NET |
| `healthcare` | Patients, appointments, records, prescriptions, providers. PHI/HIPAA-bound. | EHR integration, audit-heavy |
| `real-estate` | Listings, agents, leads, viewings, transactions. Map-heavy. | Next.js / Rails + Postgres + PostGIS |
| `logistics` | Shipments, carriers, tracking, addresses, delivery. | Real-time, geo-heavy |
| `saas-b2b` | Workspaces, teams, members, plans, usage, billing, invitations. | Multi-tenant by design |
| `content` | Articles, authors, comments, taxonomies, subscriptions. CMS-flavored. | Headless CMS / Hugo / Ghost / WordPress |
| `social` | Users, posts, likes, comments, feed, notifications, friends. | Feed algorithms, fanout, real-time |
| `affiliate` | Affiliates, programs, links, attribution, commissions, payouts. | Tracking-heavy, fraud-aware |
| `restaurant-pos` | Menu, tables, kitchen, orders, delivery, payments. | Realtime UI, tablet-driven |
| `on-demand` | Workers + requests + dispatch + ratings (Uber/Talabat-like). | Geo + real-time + matching |

## Each domain folder contains

```
<domain>/
├── glossary.md          # Entities + vocabulary specific to this domain
├── core-flows.md        # Canonical user journeys (what every project of this type must support)
├── feature-checklist.md # The 80%-of-projects-need-this list — what's typically missing in v1
├── compliance.md        # Regulatory + legal concerns (PCI, GDPR, HIPAA, FERPA, etc.)
├── stakeholders.md      # Roles + what each one needs from the system
├── anti-patterns.md     # Domain-specific mistakes that don't show up in generic code review
└── factories.md         # OPTIONAL — required only when run sets `--with-factories` OR a factory framework (Faker / factory_boy / FactoryBot / fishery) is detected in deps. Phase 4.0.3 step 7 emits a WARN (not HALT) when missing without those triggers. Per Hard rule A34 (severity: should).
```

These files get COPIED (or referenced) into the user's `ai/` knowledge base when their project's domain is detected — into `ai/business-domain.md`, `ai/core/glossary.md` (entity inventory lives inline here), etc.

## Detection signals (Phase 2 of `/setup-project`)

Each domain's `glossary.md` declares the entity names + folder names + dependencies that ID the domain. Detection runs:

1. **Entity/model names**: scan for `Order` + `Cart` + `Product` (ecommerce) vs `Course` + `Lesson` + `Enrollment` (LMS) vs `Patient` + `Encounter` + `Prescription` (healthcare).
2. **Folder names**: `apps/shop`, `cart/`, `checkout/` → ecommerce. `courses/`, `lessons/` → LMS. `policies/`, `claims/` → insurance.
3. **Dependencies**: `stripe` + `medusajs` + `cart-related libs` → ecommerce. `learnpress`, `tutor-lms`, `moodle` deps → LMS. `acme-fhir`, `hl7` libs → healthcare.
4. **Routes**: `/courses`, `/lessons`, `/checkout`, `/policies/[id]/claim` give it away.
5. **Repository name + README**: cheap hint, don't over-rely.

When 2+ signals from different domains conflict, ask one consolidated question:
> "I see signals for both ecommerce (Order, Product, cart/) and marketplace (Seller, Commission). Treat as a marketplace (multi-seller), or a single-vendor ecommerce store?"

## Multiple domains in one project

Projects are often unions:
- "ecommerce + affiliate" — a store that pays affiliates for referrals.
- "lms + saas-b2b" — corporate training sold per-seat.
- "marketplace + logistics" — a marketplace that owns last-mile delivery.

When detected, apply BOTH domain packs — the entities, flows, and anti-patterns combine.

## Adding a new domain

1. Create `business-domains/<name>/` with the 6 files.
2. List it in this README.
3. Add detection signals in `glossary.md`.
4. Test by running `/setup-project` against a real project of that type and checking what it produces.
