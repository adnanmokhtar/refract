# ADR-0003 — Where member-account guardrails live

Status: accepted · 2026-04-11 · deciders: platform lead, finance controller

## Context

The AWS organisation has a management account and four member accounts: prod (111111111111),
preview (222222222222), analytics (333333333333) and data (444444444444). Budgets and Cost Anomaly
Detection can be declared in each member account's own Terraform root or centrally.

## Decision

- **prod** declares its own budget and anomaly monitor in `infra/terraform/envs/prod/budgets.tf`.
- **analytics** has no guardrail in this repository: its budget `qw-analytics-monthly` (forecast
  80 % and actual 100 %, to finops@quaywise.example) is managed in the org-billing repository
  (`org-billing/budgets/analytics.tf`), next to the organisation's member-account anomaly monitor
  `org-linked-accounts` (DIMENSIONAL, SERVICE), which covers analytics and preview.
- **data** declares its own in the CloudFormation stack `infra/cloudformation/data-account.yaml`.

## Consequences

A guardrail for analytics is changed by a pull request to org-billing, not here.
