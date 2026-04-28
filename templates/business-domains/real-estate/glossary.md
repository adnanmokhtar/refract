# Real estate — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `real-estate`:

**Entity / model names**: `Listing`, `Property`, `Address`, `Agent`, `Brokerage`, `Lead`, `Viewing`, `Showing`, `Tour`, `Offer`, `CounterOffer`, `Transaction`, `Closing`, `Escrow`, `Commission`, `MLS`, `Buyer`, `Seller`, `Tenant`, `Landlord`, `Lease`, `Listing`, `OpenHouse`, `Inspection`, `Appraisal`.

**Folder / route names**: `listings/`, `properties/`, `agents/`, `tours/`, `mls-sync/`, `/listing/[mls-id]`, `/property/[id]`, `/agent/[slug]`, `/search?city=`, `/tour/book`, `/offers`.

**Dependencies**: `bridge-interactive`, `spark-api`, `mlsgrid`, `retsly`, `simplyrets`, `realogy`, `corelogic`, `mapbox`, `google-maps-platform`, `walkscore`, `melissa-data`, `smarty-streets`, `mlspin`, `rets-client`, `dotloop`, `docusign`, `hellosign`.

**Database schema**: tables for `listings` + `properties` + `agents` + `addresses` (with `lat`, `lng`) is the strongest signal. Presence of `mls_number` column near-conclusive for residential resale.

**Distinguishing variants**:
- **Resale residential** — MLS-driven, agent-mediated, `MLS#` everywhere.
- **New construction** — Builder-direct, no MLS, model homes, lot maps.
- **Rental** — `Lease` entity, `tenant_screening`, `rental_application`.
- **Commercial** — `CapRate`, `NOI`, `lease_type` (NNN/Gross/Modified), `tenants[]` per property.
- **iBuyer** — Operator buys + resells; instant offer; Property is owned by platform.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Property` | the physical real-world asset | `id, address_id, type (sfr/condo/multi/land/commercial), beds, baths, sqft, lot_sqft, year_built, apn (parcel#), legal_description` | persistent (owners change; property doesn't) |
| `Listing` | a property currently for sale/rent | `id, property_id, mls_number, list_price, status (coming_soon/active/pending/contingent/sold/expired/withdrawn), listed_at, expires_at, listing_agent_id, co_agent_id, brokerage_id, commission_offered_to_buyer_agent` | coming_soon → active → pending → sold (or withdrawn/expired) |
| `Address` | location with geo | `street, unit, city, state, postal, country, county, lat, lng, geohash, raw_input, normalized_at, validation_status` | normalized at create; immutable after geocoding |
| `Agent` | licensed professional | `id, license_number, license_state, license_expiry, npn (NRDS), brokerage_id, designations[], specialties[]` | active → inactive → suspended/expired |
| `Brokerage` | agent's firm | `id, name, license_number, e_o_insurance_expiry, designated_broker_id, mls_memberships[]` | active → terminated |
| `Lead` | prospective buyer/seller | `id, source, channel, intent (buy/sell/rent/list), name, email, phone, budget_range, timeline, preferred_areas[], assigned_agent_id, status, lifetime_value, last_contacted_at` | new → contacted → qualified → opportunity → converted / lost |
| `Viewing` / `Showing` | scheduled visit | `id, listing_id, buyer_agent_id, buyer_name, scheduled_at, duration, type (in_person/virtual/self_tour), feedback, lockbox_used` | requested → confirmed → completed → feedback_logged / no_show / cancelled |
| `Offer` | written purchase offer | `id, listing_id, buyer_id, buyer_agent_id, offer_price, earnest_money, financing_type, contingencies[], inspection_period_days, closing_date, expiration, status` | drafted → presented → accepted / rejected / countered / expired / withdrawn |
| `CounterOffer` | response to offer | `id, parent_offer_id, from (seller/buyer), changes[], status` | drafted → presented → accepted / rejected |
| `Transaction` / `Deal` | accepted offer in process | `id, listing_id, buyer_id, seller_id, accepted_offer_id, contract_date, closing_date, escrow_id, status, milestones[]` | under_contract → inspection → appraisal → financing → clear_to_close → closed (or terminated) |
| `Escrow` | third-party fund holding | `id, transaction_id, escrow_holder, account_number, deposits[], disbursements[], net_to_seller` | opened → funded → closing → closed |
| `Commission` | agent compensation | `transaction_id, total, listing_side, buyer_side, splits[], referral_fee, brokerage_split` | calculated → payable → paid (post-close) |
| `Inspection` | due-diligence inspection | `transaction_id, type (general/pest/sewer/roof), scheduled_at, inspector, report_url, findings[], buyer_response (accept/repair_request/terminate)` | ordered → completed → resolved |
| `Appraisal` | lender-required value opinion | `transaction_id, lender, appraiser, ordered_at, completed_at, appraised_value, appraisal_gap_amount, status` | ordered → in_progress → completed → reconsidered |
| `Lease` | rental contract | `id, property_id, landlord_id, tenant_ids[], start_date, end_date, monthly_rent, deposit, terms, status` | drafted → executed → active → expired/terminated |
| `Lockbox` / `Showing access` | physical key access | `listing_id, type (electronic/combo/manual), code, agent_assignments[], showing_log[]` | active → removed |

## Status state machines

**Listing:**
```
coming_soon → active → pending → sold
                ↓         ↓
            withdrawn  contingent → active (kick-out) → pending → sold
                ↓
             expired
```

**Transaction:**
```
under_contract → inspection_period
                      ↓
                 inspection_passed → appraisal
                      ↓ (or)              ↓
                 termination_notice  appraisal_passed → financing → clear_to_close → closed
                                          ↓                ↓
                                   appraisal_gap     financing_denied
                                          ↓                ↓
                                  renegotiation OR termination
```

**Offer:**
```
draft → presented → countered → countered → ... → accepted
               ↓                         ↓
            rejected                  expired
               ↓
           withdrawn
```

**Lead:**
```
new → contacted → qualified → opportunity → converted (transaction)
        ↓             ↓             ↓
      lost          lost          lost / nurture
```

## Vocabulary distinctions (don't conflate)

- **Property** vs **Listing** — Property is permanent (the parcel/structure); Listing is a sales/rental offering. One Property has many Listings over time.
- **Pending** vs **Contingent** vs **Under Contract** — Under Contract = offer accepted, in due diligence. Pending = past contingencies, awaiting close. Contingent = under contract WITH active contingency that may break (kick-out, sale-of-buyer-home).
- **List price** vs **Sold price** vs **Appraised value** vs **Assessed value** — List = ask; Sold = transacted; Appraised = lender's opinion; Assessed = tax authority's number (often very stale).
- **MLS number** vs **APN** vs **Address** — MLS# is per-listing per-MLS; APN (Assessor's Parcel Number) is per-property per-county; Address is location identifier.
- **Buyer's agent** vs **Listing agent** vs **Dual agent** vs **Transaction broker** — Listing represents seller; Buyer's represents buyer; Dual represents both (illegal in some states); Transaction broker represents the deal, neither party (state-dependent).
- **Earnest money** vs **Down payment** vs **Closing costs** — Earnest = deposit at offer; Down payment = buyer's cash equity at close; Closing costs = transaction fees.
- **Pre-qualification** vs **Pre-approval** vs **Mortgage commitment** — Pre-qual = soft assessment; Pre-approval = lender ran credit + income, conditional; Commitment = formal lender approval, conditional only on appraisal/title.
- **Showing** vs **Open house** vs **Tour** — Showing = scheduled private; Open house = scheduled public; Tour = casual marketing term, often = showing.
- **Concession** vs **Credit** vs **Reduction** — Concession = seller-paid item (closing costs); Credit = adjustment at closing; Reduction = price cut.
- **DOM** (Days on Market) vs **CDOM** (Cumulative DOM) — DOM resets on relist; CDOM counts across all relists. Sellers manipulate via re-listing.
- **NOI** vs **Cap rate** vs **GRM** (commercial/investment) — NOI = Net Operating Income; Cap rate = NOI / price; GRM = price / gross rent.

## Multi-tenancy variants

- **Single brokerage**: one brokerage's CRM. Tenant boundary = brokerage; agents within see brokerage data.
- **Multi-brokerage SaaS**: many brokerages on one platform. Strict tenant boundary; cross-brokerage data shared only via MLS.
- **MLS / RESO data layer**: federated; not multi-tenant in classic sense. MLS distributes listings to participating brokerages; rules + access tightly governed.
- **Portal** (Zillow/Trulia/Realtor.com style): aggregates listings from many MLSs + brokerages; consumer-facing; advertising model.
- **Franchise** (Keller Williams, RE/MAX): brand-level + franchisee-level data; shared brand reporting + isolated brokerage operations.
