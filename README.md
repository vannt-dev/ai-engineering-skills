# AI Engineering Skills

[![Validate skills](https://github.com/vannt-dev/ai-engineering-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/vannt-dev/ai-engineering-skills/actions/workflows/validate.yml)

A portable collection of software-engineering skills for Codex, Claude Code, OpenCode, and Google Antigravity.

The collection has one canonical source under `skills/`:

- Workflow skills define how to analyze, plan, implement, review, test, debug, and refactor.
- Stack skills add language and ecosystem-specific guidance.
- Consuming repositories keep their own architecture, business rules, commands, and authorization boundaries in `AGENTS.md` or equivalent project instructions.

Every canonical `SKILL.md` intentionally uses only the portable `name` and `description` frontmatter fields. Product-specific metadata lives outside the portable frontmatter.

## Included skills

Workflow skills:

- `analyze-requirement`
- `plan-change`
- `implement-change`
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

## Platform support

| Product | User installation | Project installation |
| --- | --- | --- |
| Codex | `~/.agents/skills` | `<repo>/.agents/skills` |
| Claude Code | `~/.claude/skills` | `<repo>/.claude/skills` |
| OpenCode | `~/.config/opencode/skills` | `<repo>/.opencode/skills` |
| Antigravity IDE | `~/.gemini/antigravity/skills` | `<repo>/.agents/skills` |

`Universal` installation avoids OpenCode duplicate-name discovery:

- canonical skills go to `.agents/skills` for Codex, OpenCode, and workspace-scoped Antigravity;
- a nested skills-directory plugin goes to `.claude/skills/ai-engineering-skills` for Claude Code;
- user-scope Universal installation also installs the canonical skills into Antigravity's global directory.

The repository contains `.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` so it can also be packaged natively for Codex or Claude Code.

## Validate

```powershell
.\scripts\validate-skills.ps1
.\scripts\test-tooling.ps1
```

The validator has no Python or third-party module dependency. It validates the intentionally restricted portable frontmatter schema, optional Codex UI metadata, reference links, collection manifest, duplicate names, and both plugin manifests.

## Install

Preview a user-level Universal installation:

```powershell
.\scripts\install-skills.ps1 -Target Universal -Scope User -WhatIf
```

Install for all supported products without duplicate OpenCode discovery:

```powershell
.\scripts\install-skills.ps1 -Target Universal -Scope User
```

Install for one product:

```powershell
.\scripts\install-skills.ps1 -Target Codex -Scope User
.\scripts\install-skills.ps1 -Target Claude -Scope User
.\scripts\install-skills.ps1 -Target OpenCode -Scope User
.\scripts\install-skills.ps1 -Target Antigravity -Scope User
```

For project scope, provide the repository root:

```powershell
.\scripts\install-skills.ps1 -Target Universal -Scope Project -ProjectRoot C:\src\my-project
```

The installer validates the collection before copying. It refuses to mix with an existing installation unless `-Overwrite` is supplied. `-Overwrite` replaces only the managed skill directories, removing stale files inside them, and writes `.ai-engineering-skills.receipt.json` with the installed version.

## Add project-specific rules

Do not copy repository architecture or business rules into these shared skills. A consuming repository should define at least:

- where source and tests live;
- supported build, lint, format, and test commands;
- architecture and dependency boundaries;
- security and data-handling constraints;
- mutation and publication approval rules.

## Contributing

See `CONTRIBUTING.md` for how to add or change a skill, and `CHANGELOG.md` for release history.
