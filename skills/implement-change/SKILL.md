---
name: implement-change
description: Implement an approved software change across one or more languages while preserving project constraints, contracts, authorization boundaries, and unrelated work. Use when the user explicitly asks to build, change, or fix code; do not use for analysis-only, planning-only, or review-only requests.
---

# Implement Change

Deliver the smallest complete change that satisfies the approved behavior and leaves the repository verifiably usable.

## Authority

Implementation authority covers only the code, tests, configuration, and documentation required by the request. It does not authorize publishing, deployment, external messages, production data changes, unrelated refactors, or destructive cleanup.

## Workflow

1. Read instructions from the workspace root to the narrowest affected directory and inspect the current implementation before editing.
2. Confirm the required behavior and stop if an unresolved decision would materially change contracts, data, security, or architecture.
3. Detect every affected stack from manifests and source. Inspect the available skills and apply every matching stack skill. The current collection includes `dotnet-engineering`, `java-engineering`, `go-engineering`, `python-engineering`, `typescript-engineering`, `database-engineering`, and `dart-engineering`.
4. Trace affected callers, consumers, contracts, state, and tests across language or service boundaries.
5. Make a minimal coherent change, preserving unrelated user work and existing conventions.
6. Add or update behavior-focused tests in proportion to regression risk.
7. Run the narrowest repository-supported checks, then any required broader verification.
8. Inspect the final diff for accidental files, generated output, secrets, formatting churn, and incomplete companion changes.

Do not invent architecture, upgrade dependencies opportunistically, weaken validation or typing to make checks pass, or treat implementation approval as permission to commit, push, deploy, or mutate external systems.

## Output

Report the implemented behavior, important files, verification results, remaining risks, and any follow-up that requires separate authority.
