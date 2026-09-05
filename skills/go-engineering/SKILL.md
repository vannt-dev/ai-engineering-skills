---
name: go-engineering
description: Implement, debug, review, refactor, and test Go projects using repository-compatible module, package, context, error, concurrency, API, and testing practices. Use when affected files include go.mod, go.work, Go source, generated Go code, or Go tests.
---

# Go Engineering

Apply idiomatic Go within the repository's existing package and service boundaries.

## Inspect First

- Read project instructions and inspect `go.mod`, `go.work`, build tags, generators, linters, formatters, and test conventions.
- Determine package ownership, exported contracts, platform constraints, and generated-file boundaries before editing.

## Engineering Guidance

- Keep interfaces small and define them at the consuming boundary when consistent with the codebase.
- Propagate `context.Context` through request-scoped I/O; do not store it in long-lived structs.
- Wrap errors with useful operation context while preserving identity for `errors.Is` and `errors.As`.
- Make goroutine ownership, cancellation, channel closure, and backpressure explicit. Every started goroutine needs a clear termination path.
- Avoid copying mutexes and other synchronization primitives. Protect shared mutable state consistently.
- Preserve zero-value behavior and distinguish absent, empty, and default values at serialization boundaries.
- Prefer table-driven tests where they improve coverage clarity, not as a mechanical requirement.

## Verification

Prefer repository scripts. Otherwise use focused package tests before broader `go test ./...`; include the race detector when concurrency risk and runtime cost justify it. Run `gofmt` or other mutating tools only within authorized scope.

Do not edit generated files directly or change module dependencies unless the task requires it.
