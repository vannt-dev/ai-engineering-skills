# AI Engineering Skills

A portable skill collection for software projects that use different programming languages and frameworks.

The collection separates three concerns:

- Workflow skills define how to analyze, plan, review, test, debug, and refactor.
- Stack skills add language and ecosystem-specific engineering guidance.
- Each consuming repository keeps its own architecture, business rules, commands, and authorization boundaries in `AGENTS.md` or equivalent project instructions.

## Included skills

Workflow skills:

- `analyze-requirement`
- `plan-change`
- `review-code`
- `test-change`
- `debug-issue`
- `safe-refactor`

Stack skills:

- `dotnet-engineering`
- `java-engineering`
- `go-engineering`
- `python-engineering`
- `typescript-engineering`
- `database-engineering`

In a polyglot repository, use the workflow skill that matches the task together with every stack skill relevant to the affected components. Project instructions override generic defaults.

## Validate

```powershell
.\scripts\validate-skills.ps1
```

## Install

Preview installation:

```powershell
.\scripts\install-skills.ps1 -Target Both -WhatIf
```

Install for Codex and Claude:

```powershell
.\scripts\install-skills.ps1 -Target Both
```

Existing skill directories are skipped by default. Pass `-Overwrite` to merge updated files into an existing installation. The installer does not delete destination files.

## Add project-specific rules

Do not copy repository architecture or business rules into these shared skills. A consuming repository should define at least:

- where source and tests live;
- supported build, lint, format, and test commands;
- architecture and dependency boundaries;
- security and data-handling constraints;
- mutation and publication approval rules.
