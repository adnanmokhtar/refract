# 7. Money as integer minor units

Date: 2026-05-11

Status: Parked

## Context

Floats lose cents in sums, and different currencies have different minor units.

## Decision

Every amount is an integer number of minor units, with its ISO 4217 currency next to it.

## Consequences

Display formatting needs the currency's exponent; `packages/py-money` provides it for Python.
