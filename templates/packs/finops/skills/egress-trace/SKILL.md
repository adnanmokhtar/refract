---
name: egress-trace
description: Trace data-transfer spend to its architectural cause — cross-zone chatter, network-address-translation charges, cross-region replication, internet egress, and cache or content-delivery misses — and attribute each line to the component pair producing it. Run when transfer is a material share of the bill, after a topology change, when a cost is unattributable to any obvious resource, and before approving a cross-zone or cross-region hop. Owns the TRANSFER branch — `unit-cost-probe` owns the per-unit arithmetic and `commitment-coverage` owns rate, neither of which applies here.
---

# Skill: egress-trace

## Premise

Data transfer is the cost line with no owner. It does not appear in an application's metrics, it is not attached to a resource anyone provisioned, and it is billed on a dimension — bytes crossing a boundary — that no engineer has in their head while writing code. It is therefore routinely the largest line nobody can explain.

Every finding names the **boundary crossed**, the **component pair**, the observed bytes, and the price with an as-of date. A transfer finding without a boundary is not a finding, because the price differs by an order of magnitude across boundaries.

## Halt conditions

- **Network flow logs unavailable** and the transfer line cannot be decomposed. Report the total, name the missing telemetry, and stop — attributing transfer by guesswork produces confident nonsense.
- **Topology unknown** — which components sit in which zone, region, and network. Transfer cost is a property of the topology, not of the code.
- **Provider boundary pricing unknown** for the boundaries in play (they differ substantially, and several bill both directions on internal crossings).
- **Managed-service internal transfer opaque** — some services bill transfer inside their own line item and expose no breakdown. Say so rather than assigning it to a component pair.

## When to run

- Transfer is more than a few percent of the bill and nobody can say why.
- After any topology change: a new zone, a new region, a service moved, a peering or gateway added.
- Before approving a design or diff that puts a component in a different zone from its data.
- When a cost is unattributable to any resource — transfer is the usual answer.
- When a content-delivery hit rate drops; every miss becomes origin egress.

## Procedure

### 1. Decompose the transfer line by boundary

Pull the transfer usage types from the cost/usage export and group them by boundary, because the price per GB differs by roughly an order of magnitude between them:

| Boundary | Typical shape | Notes |
|---|---|---|
| within a zone | usually free | if this is large and billed, check the service's own rules |
| across zones, same region | billed, often **both directions** | the most common invisible cost |
| through a network-address-translation or similar gateway | billed per GB **plus** per gateway-hour | processing charges frequently exceed the transfer itself |
| across regions | billed, higher | replication, multi-region reads, cross-region calls |
| to the internet | highest | user traffic, third-party API calls, backups to an external destination |
| from a content-delivery network to origin | miss-driven | a hit-rate drop converts directly into origin egress |

### 2. Attribute each boundary to component pairs

Use flow logs (or the equivalent) joined to resource inventory to answer: which pair of components produced these bytes, in which direction, over what period? Rank pairs by bytes.

Where a pair cannot be resolved, list it as unattributed transfer with its share — that is a telemetry finding, not a rounding error.

### 3. Find the mechanism per top pair

The recurring causes, in rough order of how much they cost:

- **A chatty pair split across zones.** Two components that exchange many small messages, placed in different zones for availability. Availability is a real reason; paying for it unknowingly is not.
- **Replicas reading across a boundary.** A read replica or cache in one zone serving clients in another.
- **A gateway on a path that could use a private endpoint.** Traffic to a managed service routed through a gateway that bills per GB, where a private endpoint would not.
- **Cross-region replication of data whose recovery objective does not require it.** Replicating everything because replication was configured at the bucket level.
- **Logs and telemetry shipped across a boundary**, often to a vendor over the internet, at full volume with no sampling.
- **Backups written to an external destination** at full size, daily, without deduplication or incremental strategy.
- **Content-delivery miss rate** from cache-busting query strings, short TTLs, or uncacheable responses.
- **Unfiltered or unprojected responses** — payload size multiplied by request volume.

### 4. Quantify the fix

For each mechanism, state the bytes it removes and the money at the boundary's price. Where the fix trades availability (co-locating a pair that was split deliberately), say so — this is a trade, and the report presents both sides rather than recommending on cost alone.

### 5. Report

```
## egress-trace — <scope> — <period>

Total transfer: <$> (<%> of bill)   Flow telemetry: <available | partial | absent>

### By boundary
| Boundary | Bytes | $ | Price/GB (as-of) | Both directions? |

### By component pair (top N)
| Source → Destination | Boundary | Bytes | $ | Mechanism | Fix | Bytes removed | $ removed | Trades away |

Unattributed transfer: <$> (<%>) — <telemetry that would resolve it>

Recommendations ranked by $ removed, each stating what it trades.
```

## Inputs

- Cost/usage export filtered to transfer usage types.
- Network flow logs or equivalent, joined to resource inventory.
- The topology: which components are in which zone, region, and network.
- Content-delivery hit-rate statistics, where a delivery network is in play.

## Outputs

- The report block above.
- Component-pair findings routed to `@cost-architect` (topology) or `@cost-reviewer` (a specific diff that introduced a hop).
- A transfer branch figure for `/cost-model` — usually the branch that was previously `NOT DERIVABLE`.

## False positives / gotchas

- **Assuming a hop is free because it is internal.** Cross-zone is internal and billed, frequently in both directions.
- **Ignoring gateway processing charges.** The per-GB processing on a gateway commonly exceeds the transfer line it accompanies.
- **Attributing by resource tags.** Transfer belongs to a *pair*, not to a resource; tag-based attribution assigns it arbitrarily to one side.
- **Reading a single day.** Replication and backup traffic is often weekly or monthly; a 24-hour window misses the largest contributors entirely.
- **Recommending co-location without naming the availability trade.** The split may have been deliberate and correct.
- **Confusing content-delivery egress with origin egress.** Delivery-network egress to users is usually cheaper than origin egress to the delivery network; improving the hit rate moves bytes between the two lines rather than removing them.
- **Treating a vendor's log ingestion as transfer only** — there is usually an ingestion charge on the far side as well, and the fix (sampling) reduces both.

## Related

### Skills
- `unit-cost-probe` — receives the transfer branch this skill makes derivable.
- `spend-anomaly-triage` — a transfer spike is one of the hardest anomalies to attribute without this skill.

### Agents
- `@cost-architect` — topology decisions are the durable fix.
- `@cost-reviewer` — catches a new cross-zone hop at diff time.

### Commands
- `/cost-review` — dispatches this skill whenever a diff touches transfer paths.
- `/cost-model` — the transfer branch.

### Patterns
- `ai/patterns/unit-economics.md`, `ai/patterns/spend-allocation.md`

### Cross-pack boundary
- The infrastructure pack's `multi-region` pattern owns the availability argument for cross-region topology; this skill owns its price.
