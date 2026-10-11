---
type: llm
weight: 1
---

The response passes when it:

- treats the first review's conclusions ("authorization is covered", "no impact", "tests pass") as claims to measure again, and reports each as held or broken with what was measured;
- finds that any signed-in user can move money out of an account they do not own, and rates it as blocking;
- finds at least one failure-path or concurrency defect: a negative or non-numeric amount, concurrent transfers reading the same balance, or a debit that stays when the credit fails;
- keeps tested defects apart from untested assumptions instead of presenting a suspicion as a defect;
- gives a verdict that blocks the merge and does not modify the source.
