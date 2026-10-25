---
name: plan-change
description: Build an implementation-ready change plan from stable requirements by mapping affected components, dependencies, sequencing, validation, rollout, and ownership. Use after requirements are resolved; do not use to invent missing product decisions.
---

# Plan Change

Create a plan another engineer or agent can execute without rediscovering the problem.

## Authority

Planning is read-only. Do not edit application source, create external tickets, publish branches, or change task status unless the user separately authorizes those actions.

## Workflow

1. Confirm the requirement or specification is stable enough to plan. Route unresolved product decisions back to requirement analysis.
2. Read repository instructions and inspect the current implementation, tests, dependency boundaries, contracts, and supported commands.
3. Identify the affected runtime flow and the smallest coherent set of changes. Detect every stack the flow crosses, a database behind an API included, and apply every matching stack skill from the collection (`dotnet-engineering`, `java-engineering`, `go-engineering`, `python-engineering`, `typescript-engineering`, `database-engineering`, `dart-engineering`).
4. Break work into ordered units with ownership, dependencies, concrete outcomes, and validation.
5. Include contract compatibility, data migration, security, observability, rollout, and rollback only when the change actually affects them.
6. Name files only after verifying they exist or clearly label a justified new path.
7. Separate required work from optional improvements; exclude unrelated refactors.

For polyglot work, sequence shared contracts and producers/consumers explicitly. Do not assume all components deploy together.

## Output

Provide assumptions, affected components, ordered implementation steps, verification commands or checks, rollout considerations, risks, and unresolved blockers. A plan must describe outcomes and invariants, not merely a list of filenames.
