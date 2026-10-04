# Codebase profile — marketly

PROJECT_KIND: fullstack-web
Languages: TypeScript (API and web)
Backend: NestJS 10 on Express, Prisma 5, PostgreSQL 15
Frontend: React 18 + Vite 5, react-router 6
Auth: RS256 JWT bearer for the SPA; `mk_sid` session cookie for /api/account
Edge: nginx (TLS terminated at the cloud load balancer), serves the SPA and /uploads
Runtime: Kubernetes, 3 API replicas; docker compose for local development
CI: GitHub Actions

## Layering contract

`*.controller.ts` → `*.service.ts` → `PrismaService`. Controllers validate input and
delegate; services own every query.

## Roles

`BUYER` (default at signup), `SELLER` (approved by an admin), `ADMIN` (staff).
