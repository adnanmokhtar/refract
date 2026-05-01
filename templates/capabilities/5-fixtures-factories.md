---
artifact: capability-5-fixtures-factories
purpose: Test fixtures + factories generation per detected business-domain (B17).
imported-by: templates/capabilities.md (index), commands/setup-project.md (orchestrator)
---

### 🏭 5. Test fixtures + factories generation (B17)

**Problem solved**: business-domain detection knows "this is ecommerce" but doesn't generate `ProductFactory`, `OrderFactory`, `CartFactory`. New modules ship without test fixtures. `add-module` has nothing to compose with.

**Design**:

#### 5.1 New pack file per business domain

```
~/.claude/templates/business-domains/ecommerce/factories.md
```

Format:

```markdown
# Ecommerce factory templates

Auto-generated when business-domain = ecommerce. Each factory is a starting point
adapted to the project's detected base test framework + ORM in Phase 4.6.

## Entities to factory

- ProductFactory      — required: name, price, sku; faker.commerce.*
- VariantFactory      — required: productId, attributes; uses ProductFactory.create()
- CartFactory         — required: customerId, items[]; uses ProductFactory + VariantFactory
- OrderFactory        — required: customerId, items[], total, status; uses CartFactory
- CustomerFactory     — required: email, phone; faker.internet.email + faker.phone
- AddressFactory      — required: country, city; respects detected i18n locales
- PaymentMethodFactory — required: type (card/cod/wallet); maps to detected payment provider
- DiscountFactory     — required: code, type, value
- TaxRuleFactory      — required: country, rate; respects multi-currency signal

## Fixtures to generate (golden values)

- fixtures/products-100.json          — 100 realistic SKUs across categories
- fixtures/orders-various-states.json — 1 order per status (pending, paid, shipped, etc.)
- fixtures/customers-multi-tenant.json — customers across 3 tenants for isolation tests
- fixtures/checkout-edge-cases.json   — coupon-plus-tax, partial-refund, COD, etc.
```

Each business domain has its own `factories.md`. Healthcare gets `PatientFactory` / `EncounterFactory`; LMS gets `CourseFactory` / `EnrollmentFactory`; etc.

#### 5.2 Phase 4.4b (business-domain content) — extended

After copying `glossary.md` / `core-flows.md` / etc., Phase 4.4b ALSO:

1. Reads `factories.md` from the matched business-domain pack.
2. For each entity listed: detects whether the codebase already has the entity (via Phase 2 codebase-profile entities scan).
3. For entities that EXIST: generate factory + fixture using the project's test framework conventions.
4. For entities NOT YET in code: add to `ai/business-domain.md` § "Domain entities (not yet implemented)" — when those entities get added later, factories materialize on next `--refresh`.

Generated paths:

```
test/factories/product.factory.ts
test/factories/order.factory.ts
test/fixtures/products-100.json
test/fixtures/orders-various-states.json
```

#### 5.3 Framework adaptation

Phase 4.6 (convention adaptation) detects:

| Detected | Factory style |
|---|---|
| Jest + TypeORM | factory-pattern with `DataSource` injection |
| Jest + Prisma | factory using `prisma.<model>.create()` |
| Vitest + Drizzle | factory using `db.insert(<table>)` |
| Pytest + SQLAlchemy | factory_boy DjangoFactory |
| pytest + Django | factory_boy DjangoModelFactory |
| Go + standard test | builder-pattern function returning `*Entity` |
| Phoenix + Ecto | ExMachina factories |

#### 5.4 Wired into `add-module` skill

`add-module` now declares:

```yaml
---
description: Scaffold new V1 module
inputs:
  - module_name
generates:
  - core/, adapters/, infrastructure/ (existing)
  - test/factories/<module>.factory.ts (NEW — uses business-domain factory pack)
  - test/fixtures/<module>-baseline.json (NEW)
---
```

#### 5.5 Hard rules

- **Every business-domain pack SHOULD ship a `factories.md`.** Required only when the run sets `--with-factories` OR a factory framework (Faker / factory_boy / FactoryBot / fishery / etc.) is detected in deps. When neither holds, missing `factories.md` is a WARN, not a HALT — Phase 4.0.3 step 7 enforces this gate.
- **Generated factories MUST be project-style-adapted.** A factory that doesn't match detected naming + base classes is a broken factory.
- **Fixtures NEVER contain real PII** even when sourced from production-like data. `faker` only.

---

