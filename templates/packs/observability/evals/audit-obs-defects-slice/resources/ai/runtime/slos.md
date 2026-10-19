# SLO registry — Harbor

Written by `slo-audit`. One row per objective in force; burn rules and specs are linked in the last column.

| slo | sli | target | window | owner | origin | rules |
|---|---|---|---|---|---|---|
| api-requests-availability | non-5xx API requests / all API requests | 99.9 % | 30d | checkout | storefront terms of service (2025) | deploy/slo/sloth/api.yml |
| admin-export-availability | completed CSV exports / requested | 99.9 % | 30d | backoffice | engineering aspiration | deploy/slo/sloth/api.yml |
| search-availability | non-5xx search requests / all | 99.5 % | 30d | catalog | measured 90d attainment 99.7 % (2026-03) | deploy/slo/sloth/api.yml |
| api-latency | API requests under 300 ms / all | 99 % | 28d | checkout | measured 90d attainment 99.4 % (2026-03) | deploy/slo/pyrra/api-latency.yaml |
| checkout-latency | checkouts completing under 250 ms / all | 99 % | 30d | checkout | storefront terms of service (2025) | deploy/prometheus/rules/slo-latency.rules.yml |
| inventory-reserve-latency | reservations under 200 ms / all | 99 % | 30d | inventory | ADR 0011 | deploy/prometheus/rules/slo-latency.rules.yml |
| payments-capture-availability | captures without error / all captures | 99.9 % | 30d | payments | PSP contract, schedule 3 | deploy/prometheus/rules/payments-slo.rules.yml |
| partner-webhooks-delivery | delivered partner webhooks / all | 100 % | 30d | billing | fulfilment partner agreement | deploy/slo/openslo/partner-webhooks.yaml |
| storefront-checkout-success | confirmed checkouts / submitted (RUM) | 99.5 % | 30d | web | storefront terms of service (2025) | deploy/monitors/datadog.tf |
| search-latency | search requests under 400 ms / all | 99 % | 30d | catalog | measured 90d attainment 99.3 % (2026-03) | — |
