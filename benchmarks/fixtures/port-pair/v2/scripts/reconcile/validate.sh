#!/usr/bin/env bash
# Reconciliation between the V1 MySQL replica and the V2 Postgres target, with Google's Data
# Validation Tool (data-validation 8.x). Runs after each backfill and again after CDC catch-up.
set -euo pipefail

SRC=v1_mysql
TGT=v2_pg

# Orders: counts, money aggregates and timestamps per table, then row level on money and status.
data-validation validate column -sc "$SRC" -tc "$TGT" -tbls norrow.orders=public.orders --count '*' --sum total_amount --min total_amount --max total_amount --wildcard-include-timestamp
data-validation validate row -sc "$SRC" -tc "$TGT" -tbls norrow.orders=public.orders -pk number --comparison-fields status,currency,total_amount,po_number

# Invoices.
data-validation validate column -sc "$SRC" -tc "$TGT" -tbls norrow.invoices=public.invoices --count '*'

# Users.
data-validation validate row -sc "$SRC" -tc "$TGT" -tbls norrow.users=public.users -pk email --hash '*' -cim

# Stock: counts and quantity sums.
data-validation validate column -sc "$SRC" -tc "$TGT" -tbls norrow.stock_items=public.stock_items --count '*' --sum quantity_available,quantity_reserved

# Tickets: live rows only on the V1 side (ADR-0010 filters soft-deleted tickets at the source).
data-validation validate custom-query column -sc "$SRC" -tc "$TGT" --source-query "SELECT COUNT(*) AS n, SUM(priority) AS p FROM tickets WHERE deleted_at IS NULL" --target-query "SELECT COUNT(*) AS n, SUM(priority) AS p FROM tickets" --sum n,p

# Order and invoice lines: counts and money aggregates.
data-validation validate column -sc "$SRC" -tc "$TGT" -tbls norrow.order_lines=public.order_lines --count '*' --sum quantity,net_amount --min net_amount --max net_amount
data-validation validate column -sc "$SRC" -tc "$TGT" -tbls norrow.invoice_lines=public.invoice_lines --count '*' --sum quantity,net_amount --min net_amount --max net_amount
