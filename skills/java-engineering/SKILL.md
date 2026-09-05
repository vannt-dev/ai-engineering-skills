---
name: java-engineering
description: Implement, debug, review, refactor, and test Java projects using repository-compatible JDK, Maven or Gradle, framework, concurrency, transaction, and testing practices. Use when affected files include pom.xml, Gradle builds, Java source, JVM configuration, or Java test code.
---

# Java Engineering

Apply Java-specific guidance while preserving the repository's chosen architecture and framework.

## Inspect First

- Read project instructions and identify the JDK/toolchain version, Maven or Gradle wrapper, modules, dependency management, static analysis, formatting, and test framework.
- Use the checked-in wrapper when present. Do not substitute a system Maven or Gradle version without a reason.
- Activate Spring, Jakarta EE, Quarkus, Micronaut, Android, or other framework guidance only when the project actually uses it.

## Engineering Guidance

- Preserve package and module boundaries; avoid exposing implementation types through public contracts.
- Model nullability and optional values consistently with the existing code. Do not use `Optional` as a universal replacement for nullable fields.
- Keep transaction boundaries at the established service or repository layer and account for proxy-based framework behavior.
- Make thread safety explicit for shared mutable state, executors, futures, reactive streams, and virtual threads.
- Preserve exception semantics and causal chains; do not catch broad exceptions merely to log or return null.
- Match existing serialization, validation, dependency injection, and persistence conventions.
- Reuse JUnit, assertion, mocking, container, and fixture libraries already selected by the repository.

## Verification

Prefer repository scripts and wrapper tasks. Start with the affected module and focused test, then broaden to the required Maven or Gradle lifecycle checks. Formatting and auto-fix tasks are mutations and require implementation authority.

Do not change the JDK, dependency versions, build plugins, or framework conventions unless the task requires it.
