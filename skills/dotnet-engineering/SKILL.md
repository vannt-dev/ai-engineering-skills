---
name: dotnet-engineering
description: Implement, debug, review, refactor, and test C# or .NET projects using repository-compatible SDK, project, dependency injection, async, API, data-access, and testing practices. Use when affected files include .sln, .csproj, .fsproj, .cs, .fs, or .NET build configuration.
---

# .NET Engineering

Apply .NET-specific guidance without imposing one application architecture.

## Inspect First

- Read project instructions and locate `global.json`, solution files, project files, central package management, analyzers, formatters, and test projects.
- Confirm target frameworks, language version, nullable settings, implicit usings, and warnings policy from source rather than assuming the latest SDK.
- Follow the repository's existing architecture and dependency direction.

## Engineering Guidance

- Preserve async end-to-end. Pass `CancellationToken` through I/O boundaries when the local contract supports cancellation; avoid sync-over-async.
- Validate dependency injection lifetimes across singleton, scoped, and transient consumers. Do not resolve scoped services from the root provider.
- Treat nullable annotations as contracts. Do not silence warnings with `!` without evidence.
- Keep resource ownership explicit with `using` or `await using`; do not dispose injected dependencies owned by the container.
- For ASP.NET Core, preserve routing, binding, validation, authorization, status codes, error contracts, and cancellation behavior.
- For data access, preserve transaction ownership and parameterize values. Apply ORM- or driver-specific patterns only when that dependency is present.
- Match the established test framework and assertion library.

## Verification

Prefer repository scripts. Otherwise derive the narrowest valid `dotnet restore`, `dotnet build`, and `dotnet test` commands from the actual solution or project structure. Run formatting only when authorized because formatters mutate files.

Do not upgrade SDKs, packages, analyzers, language versions, or project style unless the task requires it.
