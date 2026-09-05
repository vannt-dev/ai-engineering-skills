---
name: analyze-requirement
description: Turn a raw software request into an evidence-backed specification with scope, acceptance criteria, impacts, risks, and open decisions. Use for requirement analysis before planning or implementation; do not use when an approved specification already exists.
---

# Analyze Requirement

Produce a specification that separates requested outcomes from implementation guesses.

## Authority

Remain read-only unless the user explicitly asks to create or update a specification artifact. Do not modify application source, configuration, schemas, tickets, or external systems.

## Workflow

1. Read the nearest repository instructions and identify the authoritative source for current behavior.
2. Inspect the smallest relevant slice of source, tests, contracts, and configuration. In a polyglot system, follow the request across affected service and language boundaries.
3. State the user-visible goal, actors, triggers, inputs, outputs, invariants, failure behavior, and non-goals.
4. Distinguish confirmed facts, evidence-backed inferences, and unresolved decisions.
5. Ask only questions whose answers would materially change scope, behavior, data, security, compatibility, or delivery.
6. Define testable acceptance criteria without prescribing an implementation unless the constraint is confirmed.
7. Record affected components, contracts, data, operational concerns, risks, and rollout or compatibility needs.

Do not infer behavior from folder names or architecture summaries when executable source is available. Do not invent file paths, APIs, schema objects, or business rules.

## Output

Return a concise specification containing scope, non-goals, current evidence, desired behavior, acceptance criteria, impact areas, risks, and open decisions. Stop before implementation planning when a material decision remains unresolved.
