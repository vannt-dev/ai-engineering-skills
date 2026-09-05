---
name: database-engineering
description: Design, review, debug, migrate, and test relational database changes with engine-aware SQL, parameter safety, transaction analysis, compatibility, rollout, and rollback planning. Use when a task affects SQL, schemas, migrations, queries, indexes, transactions, or relational data access.
---

# Database Engineering

Treat the application query path and deployed schema as one contract.

## Inspect First

1. Read project instructions and identify the authoritative schema and migration mechanism.
2. Confirm the database engine and supported version from configuration or source.
3. Trace affected queries, parameters, result mappings, transactions, callers, and tests.
4. Determine whether migrations are forward-only, reversible, online, operator-run, or tool-managed.

When the engine is PostgreSQL, read [references/postgresql.md](references/postgresql.md). For another engine, follow its current project conventions and verified engine documentation rather than applying PostgreSQL syntax by analogy.

## Core Rules

- Parameterize data values. Dynamic identifiers and clauses must come from trusted internal mappings or allowlists.
- Preserve transaction ownership, isolation assumptions, idempotency, and retry semantics.
- Design schema changes for existing rows, mixed application versions, locking, deployment order, and failure recovery.
- Add constraints and indexes for demonstrated integrity or access needs, accounting for write and storage cost.
- Verify affected result shapes, nullability, precision, collation, time zones, and generated values.
- Never run write SQL against a shared, staging, or production database without explicit authorization and a confirmed target.
- Never expose credentials, connection strings, tokens, or sensitive row data.

## Verification

Use the repository's migration and database test tooling. Validate syntax and behavior in an isolated database when available. Treat execution plans and estimated costs as environment-dependent evidence, not universal guarantees.
