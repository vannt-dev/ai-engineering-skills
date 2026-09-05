---
name: test-change
description: Design or implement behavior-focused tests for software changes across languages and frameworks. Use for test strategy, regression coverage, or writing tests; do not change production behavior unless the user explicitly includes implementation fixes.
---

# Test Change

Choose tests that demonstrate externally meaningful behavior and failure handling.

## Authority

For test-planning requests, remain read-only. For test implementation, edit test code and test support only; production changes require separate authorization.

## Workflow

1. Read repository instructions, existing test conventions, and the behavior being changed.
2. Identify the observable contract, important invariants, trust boundaries, failure modes, and regression risk.
3. Select the narrowest test level that proves each behavior: unit, component, integration, contract, or end-to-end.
4. Reuse established fixtures and helpers. Avoid introducing a new framework when the repository already has one.
5. Cover meaningful success, boundary, invalid-input, authorization, state-transition, retry, concurrency, or compatibility cases when relevant.
6. Keep tests deterministic. Control time, randomness, external services, and shared state explicitly.
7. Run the repository-supported command for the affected test scope before broader suites.

Do not write tests that merely mirror implementation structure, assert generated wording, or pass only because dependencies are over-mocked. A regression test should fail for the original defect and pass for the intended behavior.

## Output

Report coverage added or proposed, commands run, results, untested risks, and any production defect revealed by the tests.
