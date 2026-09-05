---
name: debug-issue
description: Diagnose software failures across languages by reproducing symptoms, tracing control and data flow, testing hypotheses, and identifying the smallest supported cause. Use for bugs, crashes, incorrect results, flaky tests, or production symptoms; diagnosis alone does not authorize a fix.
---

# Debug Issue

Build an evidence chain from observed symptom to root cause.

## Authority

Diagnosis is read-only unless the user explicitly requests a fix. Non-mutating inspection, local reproduction, and relevant tests are permitted under repository instructions.

## Workflow

1. Capture expected behavior, actual behavior, environment, frequency, inputs, and the earliest known failing boundary.
2. Read project instructions and inspect recent relevant changes before forming a preferred explanation.
3. Reproduce with the smallest reliable case when practical. Preserve logs and exact errors without exposing secrets.
4. Trace the request, event, state, or data through affected components. In polyglot systems, verify serialization, protocol, version, and error mapping at each boundary.
5. Rank a small set of falsifiable hypotheses, then use targeted evidence to eliminate them.
6. Confirm the root cause explains all material symptoms and distinguish contributing conditions.
7. Propose the smallest safe fix and a regression test, but do not implement them without authority.

Avoid shotgun edits, speculative dependency upgrades, and suppressing the symptom through broader retries or exception handling.

## Output

Report reproduction status, evidence, root cause, affected scope, recommended fix, regression coverage, and remaining uncertainty.
