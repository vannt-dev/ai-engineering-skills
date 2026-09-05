---
name: python-engineering
description: Implement, debug, review, refactor, and test Python projects using repository-compatible runtime, packaging, typing, async, resource, framework, and testing practices. Use when affected files include pyproject.toml, setup configuration, requirements files, Python source, notebooks, or Python tests.
---

# Python Engineering

Apply Python-specific guidance without replacing the repository's selected package manager, framework, or style.

## Inspect First

- Read project instructions and inspect `pyproject.toml`, lockfiles, supported Python versions, environment manager, type checker, linter, formatter, and test configuration.
- Determine whether the code is synchronous, asyncio-based, framework-managed, generated, or notebook-oriented before applying patterns.

## Engineering Guidance

- Preserve public call signatures, exception behavior, serialization, and type contracts.
- Use precise types at boundaries. Narrow `Any` and untrusted data rather than spreading them through the codebase.
- Keep blocking I/O out of an active event loop and preserve cancellation in asynchronous flows.
- Manage files, streams, database sessions, locks, and clients with explicit context or lifecycle ownership.
- Avoid mutable default arguments and hidden process-global state.
- Preserve import direction and avoid circular-import workarounds that conceal an architectural issue.
- Reuse established pytest, unittest, fixture, mocking, and property-testing conventions.

## Verification

Use the repository's environment and scripts. Run focused tests and configured type or lint checks before broader suites. Formatters and notebook normalization mutate files and require implementation authority.

Do not install or upgrade dependencies, change lockfiles, or create a new environment strategy unless the task requires it.
