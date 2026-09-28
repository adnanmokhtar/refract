# Parity audit: users
> V1 path: v1/app/Services/UserService.php v1/database/migrations/2020_01_01_create_users.php
> V2 path: src/users/users.service.ts prisma/schema.prisma
> Tier: trivial
> Verdict: PARITY

## Findings
### 1. Endpoints
POST /users and GET /users match V1.
