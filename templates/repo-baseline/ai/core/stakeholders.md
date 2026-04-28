# Stakeholders

Roles + their workflows + their KPIs + what irritates them. Auto-populated from `business-domains/<domain>/stakeholders.md` when a business domain is detected. Otherwise: filled in as the team identifies who interacts with the system.

## Per-stakeholder template

```
## <Role>
The <one-sentence summary of who they are>.

### Workflows
- <action they take>
- <action>

### Pain points
- <what frustrates them about the system today>
- <what frustrates them about competing alternatives>

### KPIs
- <metric they care about>
- <metric>

### Permissions / scope
- <what they can see / do>
- <what they explicitly cannot>
```

## Stakeholders to fill in

- Customer / end-user
- Operator / admin
- Support staff
- Developer / engineering
- Compliance / legal (if applicable)
- External integrations / partners
- Investors / leadership (rare; for KPI alignment)

## Cross-stakeholder priorities

When deciding what to build:

| Friction signal from... | Then priority is... |
|---|---|
| <Role> | <action that helps them> |

## How to keep this current

- Add a role when a new stakeholder appears (e.g., new admin tier, new partner integration).
- Update KPIs when business priorities shift.
- Update pain points after user research / support ticket review.

## See also

- `ai/business-domain.md` — declared product type.
- `ai/users-and-personas.md` — deeper persona detail (if populated).
- `ai/project-goals.md` — top-level KPIs the stakeholders connect to.
