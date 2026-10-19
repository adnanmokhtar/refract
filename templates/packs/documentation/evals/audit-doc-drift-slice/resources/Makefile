COMPOSE ?= docker compose
SNAPSHOT ?= latest

.PHONY: up down db-backup db-restore db-seed

up:
	$(COMPOSE) up -d postgres redis

down:
	$(COMPOSE) down

db-backup:
	./scripts/db-backup.sh

db-restore:
	./scripts/db-restore.sh $(SNAPSHOT)

db-seed:
	pnpm db:seed
