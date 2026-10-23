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
5. Make the smallest complete change. Before writing new code, take the first option that fully works: leave it out when the request does not need it (and name what you left out); reuse what this codebase already has (a helper, component, or pattern, used the way the surrounding code uses it); the standard library or platform; a dependency the project already installs; only then new code. Never add a dependency for a few lines. Smallest does not mean partial: reach every caller, test, fixture, and configuration the change affects, preserve unrelated user work and existing conventions, and never trade away validation at trust boundaries, error handling that prevents data loss, security, or accessibility.
6. When you take a deliberate shortcut with a known limit, mark it with a one-line comment `shortcut: <the limit>, <when to upgrade>`, unless the project has its own marker for deferred work. `shortcut-ledger` collects these markers later.
7. Add or update behavior-focused tests in proportion to regression risk. New logic with a branch, a loop, parsing, money, or security leaves at least one test that fails when it breaks.
8. Run the narrowest repository-supported checks, then any required broader verification.
9. Inspect the final diff for accidental files, generated output, secrets, formatting churn, and incomplete companion changes.

Do not invent architecture, upgrade dependencies opportunistically, weaken validation or typing to make checks pass, or treat implementation approval as permission to commit, push, deploy, or mutate external systems.

## Output

Report the implemented behavior, important files, verification results, what you deliberately left out or did not check, any `shortcut:` marker you added, remaining risks, and any follow-up that requires separate authority.
