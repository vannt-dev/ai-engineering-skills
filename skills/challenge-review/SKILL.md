---
name: challenge-review
description: Run an adversarial second pass over a completed code review of a high-risk change, measuring the first review's conclusions again through three independent lenses instead of trusting them. Use after review-code on changes to authentication, authorization, money, schemas, data migrations, or concurrency, or when asked for a second opinion or red-team review; do not use as the first or only review, or for low-risk changes.
---

# Challenge Review

A second review earns its cost only by attacking what the first one concluded. Treat every "verified", "safe", "no impact", and "out of scope" in the first review as a claim to measure again, not as evidence.

## Authority

Read-only, like review-code. Builds, static analysis, and tests are allowed when repository instructions permit them. Do not repair the source and do not edit the first review.

## Workflow

1. Read the first review and list its conclusions; each one is a claim to test. When no first review exists, stop and run review-code first.
2. Read the diff and the code it touches: callers, callees, contracts, and data paths. Interaction with existing code is where a first review most often stops short.
3. Measure each claim independently. Run the test, trace the path, or read the callee instead of re-reading the first reviewer's reasoning. Record the claim as held or broken, with what was measured.
4. Read the change once through each lens and keep the three sets of findings apart until step 6.
   - **Breaker** tries to make it fail in production: the worst input for each changed function; each external call failing, timing out, or returning garbage; each state change running twice, concurrently, or never.
   - **Newcomer** must change this code in six months without the author: names that hide what the code does, logic that needs several other files to follow, constants with no stated meaning, tests bound to implementation instead of behavior.
   - **Attacker** looks for the trust boundary the change crosses: input reaching a query or command, a new route or action with no authorization check, another user's or tenant's data becoming reachable, secrets or personal data in logs, errors, or responses.
5. End each lens with at least one finding or, when it finds no defect, the single assumption the code depends on most and how that assumption was tested. A lens that reports only "nothing found" has not run.
6. Merge duplicates. A finding reached independently through two or more lenses moves up one severity tier.
7. Counter the bias of reviewing code just read or written: start from the last changed function and work backward, state each function's contract before reading its body, and ask what would break if the change were deleted.

Do not soften a finding, restate the diff as a finding, or present an untested suspicion as a defect; label it an assumption and say what would confirm it. Do not invent a finding to satisfy a lens.

## Output

Use the severity tiers and categories of review-code. Report in this order:

1. The verdict: `block` when a critical or high finding stands, `concerns` when a medium finding stands, `clean` otherwise.
2. Each claim from the first review, held or broken, with the measurement.
3. Findings by severity, each with exact location, failing scenario, impact, and the lenses that reached it.
4. The assumptions recorded in step 5.
