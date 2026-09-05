---
name: review-code
description: Review source changes across languages for functional defects, regressions, security risks, contract breaks, data hazards, concurrency issues, and missing tests. Use for diffs, pull requests, or completed implementations; do not modify code unless fixes are explicitly requested.
---

# Review Code

Prioritize defects that can change observable behavior or operational safety.

## Authority

Review is read-only. Builds, static analysis, and tests are allowed when repository instructions permit them, but generated changes must not be silently committed or reformatted.

## Workflow

1. Read repository instructions and determine the intended base and scope of the change.
2. Inspect the actual diff, then trace affected callers, callees, contracts, data paths, and tests.
3. Apply guidance for every relevant language, framework, database, and deployment boundary.
4. Check correctness, authorization, input trust boundaries, error behavior, compatibility, transactions, concurrency, resource lifetime, and operational failure modes.
5. Run the narrowest meaningful verification available. Report actual results and distinguish pre-existing failures.
6. Avoid style-only findings unless the style rule is enforced or creates a concrete maintenance or correctness risk.

## Findings

Each finding must include severity, exact location, failing scenario, impact, and a practical direction for correction. State when a concern is an inference rather than a verified defect. If no findings remain, say so and identify verification gaps or residual risks.
