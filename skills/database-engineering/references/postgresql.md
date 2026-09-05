# PostgreSQL Guidance

Use the PostgreSQL version supported by the project. Verify feature availability before choosing recent syntax.

## Queries and data access

- Use bind parameters for values. PostgreSQL parameters cannot represent identifiers, sort directions, keywords, or arbitrary SQL fragments; select those through trusted mappings.
- Use `INSERT ... ON CONFLICT` only with a confirmed unique or exclusion arbiter and explicitly chosen `DO NOTHING` or `DO UPDATE` behavior.
- Preserve the distinction between `NULL`, empty values, missing JSON fields, and database defaults.
- Confirm time-zone semantics for `timestamp with time zone` and `timestamp without time zone` at application boundaries.
- Use `EXPLAIN` for plan inspection; use `EXPLAIN ANALYZE` only where executing the statement and its side effects is safe.

## Migrations

- Assess table rewrites, lock levels, index-build strategy, long transactions, and validation cost on populated tables.
- Stage incompatible changes with expand-and-contract when old and new application versions may overlap.
- Backfills should be bounded, restartable, observable, and safe to repeat when operational constraints require batching.
- Create explicit constraints for actual integrity rules and give operationally meaningful names when the project convention requires them.
- A rollback plan must account for data written in the new shape; reversing DDL alone may not restore compatibility.

## Concurrency

- Define the invariant before selecting row locks, advisory locks, optimistic concurrency, or isolation levels.
- Keep lock acquisition ordering consistent and transactions as short as the business invariant permits.
- Retries must be bounded and limited to failures that are safe to repeat.
