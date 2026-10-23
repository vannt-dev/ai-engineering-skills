---
name: review-code
description: Review source code and changes across languages for functional defects, regressions, security risks, contract breaks, data hazards, concurrency issues, and missing tests. Use whenever asked to review, audit, or find what is wrong in code, whether a diff, a pull request, a completed implementation, a file, or a snippet, and whenever asked about the status or evidence of a code review; do not modify code unless fixes are explicitly requested.
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
7. For a change to authentication, authorization, money, schemas, data migrations, or concurrency, recommend a second pass with challenge-review once this review is complete.

## Findings

Every finding needs a concrete case: the input or situation that leads to the wrong result. Before reporting, re-read the lines and confirm the case holds: the caller exists, the value can be empty, the code is unused. A concern without a confirmed case is an inference; label it as one. When a finding depends on scale, say which load you assumed (one person running a script, or many users and processes at once) and where in the repository that load is stated.

A deliberate shortcut marked with a `shortcut: <the limit>, <when to upgrade>` comment is a recorded decision, not a finding, unless the expected load already crosses the limit it names.

Write for a reader who has never seen this code: short sentences, everyday words, and each technical term explained the first time it appears. Number the findings in one sequence across all severities, so the user can answer "fix 2 and 5". Each finding gives severity, category, and exact location, then four short parts:

- **What this is:** what the code does, in one sentence.
- **Problem:** the failing scenario and the wrong result it produces.
- **Fix:** the smallest correction that works; prefer one that removes code.
- **If we skip it:** the impact on users, data, or operations.

```text
2. high · correctness: Retry can charge a card twice (`billing/charge.py:31-44`)
   - What this is: `charge()` calls the payment provider and retries once on a timeout.
   - Problem: a timeout does not mean the first call failed. When it succeeded late, the retry charges again.
   - Fix: send the same idempotency key on both attempts.
   - If we skip it: some customers pay twice, and support refunds them by hand.
```

End the review with two lines: `Verdict:` ship, or which numbered findings to fix first; and `Not checked:` what mattered but could not be read or run. If no findings remain, say so, name what was checked, and identify verification gaps or residual risks.

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
