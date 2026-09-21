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

Each finding must include severity, category, exact location, failing scenario, impact, and a practical direction for correction. State when a concern is an inference rather than a verified defect. If no findings remain, say so and identify verification gaps or residual risks.

### Scope Supplied by the Harness

When the workflow supplies a resolved file list, requirement background, or output from a review tool (for example a Junto plan or an OpenCodeReview delegate preview), review exactly that scope and judge whether the change satisfies the stated requirement. Treat tool findings as inputs to verify, not verdicts, and report them with the severity tiers and categories below so they can be normalized. Never state that a build, test, or review gate passed unless a command result shows it.

Check that review evidence belongs to the current source, refs, policy, and requirement context. Source edits after or during review require fresh evidence, including edits made through shell commands or external editors. A successful delegate preview or rule lookup confirms file/rule selection only; it does not establish that a model reviewed the source. Explicitly distinguish mock results, fixture validation, and live semantic review.

### Severity Tiers
- **critical**: Active exploitability, critical data loss, or blocking service failures.
- **high**: Broken business contracts, severe performance degradation, authentication/authorization leaks, or unhandled exceptions.
- **medium**: Logic bugs in edge cases, missing input validation, or concurrency hazards.
- **low**: Minor maintainability issues, missing test coverage, or localized inefficiencies.
- **info**: Non-blocking suggestions, clean-code improvements, or advisory notes.

### Categories
- `security`: Authentication, authorization, cryptography, input validation, injection.
- `correctness`: Functional defects, logic errors, broken contracts, data integrity.
- `performance`: Latency bottlenecks, memory leaks, query efficiency, resource starvation.
- `maintainability`: Complexity, readability, coupling, cohesion, dead code.
- `testing`: Missing test coverage, brittle assertions, untested edge cases.
- `architecture`: Layering violations, circular dependencies, boundary leaks.
- `other`: General findings not fitting standard categories.
