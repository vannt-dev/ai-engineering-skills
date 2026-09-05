---
name: safe-refactor
description: Plan or execute behavior-preserving refactors across languages with dependency analysis, contract protection, incremental edits, and regression verification. Use for restructuring, renaming, extraction, dependency cleanup, or modernization where observable behavior should remain stable.
---

# Safe Refactor

Preserve externally observable behavior unless a behavior change is explicitly included in scope.

## Workflow

1. Read repository instructions and define the behavior and contracts that must remain unchanged.
2. Map references, consumers, public APIs, serialization formats, database interactions, configuration keys, generated code, and deployment coupling relevant to the target.
3. Establish characterization or regression coverage when existing tests do not protect critical behavior.
4. Split the refactor into small coherent transformations with a verifiable state after each one.
5. Prefer repository-supported rename and analysis tools. Inspect generated edits before accepting them.
6. Preserve comments, documentation, formatting conventions, and unrelated user changes.
7. Run focused verification after each risky boundary change and the required broader checks before completion.

Do not mix opportunistic behavior changes, dependency upgrades, or broad formatting into the refactor. If safe preservation cannot be demonstrated, stop and describe the missing evidence.

## Output

Summarize transformed boundaries, preserved contracts, verification performed, and residual compatibility or rollout risks.
