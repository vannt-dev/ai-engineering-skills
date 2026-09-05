---
name: typescript-engineering
description: Implement, debug, review, refactor, and test TypeScript projects using repository-compatible compiler, package manager, runtime, framework, contract, async, and testing practices. Use when affected files include tsconfig files, TypeScript source, typed JavaScript, package manifests, or TypeScript tests.
---

# TypeScript Engineering

Preserve type and runtime contracts across browser, server, package, and API boundaries.

## Inspect First

- Read project instructions and inspect `package.json`, lockfiles, workspace configuration, `tsconfig` inheritance, module mode, runtime, framework, linter, formatter, and test runner.
- Use the package manager selected by the lockfile and repository scripts.
- Determine generated-code, client/server, SSR, and public-package boundaries before editing.

## Engineering Guidance

- Prefer `unknown` plus narrowing for untrusted data. Do not introduce `any`, unsafe assertions, or ignored diagnostics merely to satisfy the compiler.
- Preserve optional, nullable, absent, and discriminated-union semantics at API and serialization boundaries.
- Keep runtime validation where static types cannot protect external input.
- Preserve promise rejection and cancellation behavior; avoid floating promises and broad error swallowing.
- Respect module format, tree-shaking, side-effect, and server-versus-browser constraints.
- Avoid duplicating server contracts manually when an established generation or shared-schema flow exists.
- Reuse the repository's test runner, component tools, and fixtures.

## Verification

Run focused repository scripts for type checking, tests, and linting before broader checks. Auto-fix and formatting commands mutate files and require implementation authority.

Do not change package manager, compiler mode, framework version, dependencies, or lockfiles unless the task requires it.
