# Acme Fulfilment

Order intake, warehouse picking, carrier booking, cash-on-delivery settlement and customer notifications.

| Root | What runs there |
|---|---|
| `apps/api` | NestJS 11 on Fastify: the public and admin API, producers, the outbox relay, crons |
| `apps/worker` | the same monorepo's worker image: BullMQ processors, kafkajs and amqplib consumers, projections |
| `apps/workflows-ts` | Temporal TypeScript workers (fulfilment, returns, linehaul, manifests) |
| `apps/web` | the merchant console (React Router 7) |
| `services/billing-py` | Django 6 + Celery 5.6 on Redis: invoices, tax quotes, ERP export |
| `services/ledger-jvm` | Spring Boot 3.5: the ledger, postings, statements, Temporal settlement |
| `services/dispatch-go` | Go 1.25: courier dispatch, route workflows, the leader-elected dispatcher |
| `services/notify-dotnet` | .NET 9: notification preferences, SMS and e-mail delivery |
| `schemas/` | event contracts: protobuf, Avro, AsyncAPI 3, JSON Schema |
| `deploy/` | Kubernetes, Terraform, broker definitions, Debezium, the Kafka hosts |

Production runs on a self-hosted k3s cluster in Frankfurt (`deploy/cluster`), the Kafka brokers on three VMs
(`deploy/kafka`), RabbitMQ and NATS in-cluster, managed Postgres behind PgBouncer, and two Redis servers: the job
Redis in-cluster (`deploy/redis.conf`) and a managed Valkey for notifications.
