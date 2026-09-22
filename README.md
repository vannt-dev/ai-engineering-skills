# AI Engineering Skills

[![Validate skills](https://github.com/vannt-dev/ai-engineering-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/vannt-dev/ai-engineering-skills/actions/workflows/validate.yml)
[![Consumer smoke](https://github.com/vannt-dev/ai-engineering-skills/actions/workflows/consumer-smoke.yml/badge.svg)](https://github.com/vannt-dev/ai-engineering-skills/actions/workflows/consumer-smoke.yml)

A portable collection of software-engineering skills for Codex, Claude Code, OpenCode, and Google Antigravity.

[Explore the collection and installation guide →](https://vannt-dev.github.io/ai-engineering-skills/)

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
- `checkpoint-progress`

Stack skills:

- `dotnet-engineering`
- `java-engineering`
- `go-engineering`
- `python-engineering`
- `typescript-engineering`
- `database-engineering`
- `dart-engineering`

In a polyglot repository, use the workflow skill that matches the task together with every stack skill relevant to the affected components. Project instructions override generic defaults.

## Platform support

| Product | User installation | Project installation |
| --- | --- | --- |
| Codex | `~/.agents/skills` | `<repo>/.agents/skills` |
| Claude Code | `~/.claude/skills` | `<repo>/.claude/skills` |
| OpenCode | `~/.config/opencode/skills` | `<repo>/.opencode/skills` |
| Antigravity | `~/.gemini/config/skills` | `<repo>/.agents/skills` |

`Universal` installation uses the shared Agent Skills locations where practical:

- canonical skills go to `.agents/skills` for Codex, OpenCode, and workspace-scoped Antigravity;
- a nested skills-directory plugin goes to `.claude/skills/ai-engineering-skills` for Claude Code;
- user-scope Universal installation also installs the canonical skills into Antigravity's global directory at `.gemini/config/skills`.

[OpenCode V2](https://opencode.ai/v2/docs/skills) recursively discovers `SKILL.md` files below `.claude/skills`, so it may also see the Claude plugin copies during a Universal installation. It resolves those duplicate IDs by source precedence, with `.agents/skills` taking precedence over `.claude/skills`. Use the direct `OpenCode` target when a single discovery source is required.

The repository contains `.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` so it can also be packaged natively for Codex or Claude Code.

## Validate

```powershell
.\scripts\validate-skills.ps1
.\scripts\validate-evals.ps1
.\scripts\test-tooling.ps1
```

The validators have no Python or third-party module dependency. They validate the intentionally restricted portable frontmatter schema, optional Codex UI metadata, reference links, collection manifest, duplicate names, plugin manifests, published JSON Schemas, and behavioral eval fixture structure.

The `schemas/` directory publishes contracts for `skillset.json`, installation receipts, and both plugin metadata formats. Behavioral cases live under `evals/`. To execute them with Claude Code, an authenticated CLI, and an explicit cost ceiling:

```powershell
.\scripts\run-behavior-evals.ps1 -Runs 1 -Threshold 0.75 -MaxCostUsd 2
```

## Install

Download the [1.1.0 release](https://github.com/vannt-dev/ai-engineering-skills/releases/tag/v1.1.0)
and extract it, or check out the versioned source:

```bash
git clone --branch v1.1.0 --depth 1 https://github.com/vannt-dev/ai-engineering-skills.git
cd ai-engineering-skills
```

Run the commands below from the extracted collection directory. For an existing managed
installation, run the installer from this version with `-Overwrite`; preview first with `-WhatIf`.
The receipt records version 1.1.0. Unrelated skills are preserved.

Preview a user-level Universal installation:

```powershell
.\scripts\install-skills.ps1 -Target Universal -Scope User -WhatIf
```

Install for all supported products:

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

The installer validates and stages the complete collection before copying. It refuses to mix with an existing installation unless `-Overwrite` is supplied. `-Overwrite` replaces only directories identified by an `.ai-engineering-skills.receipt.json` receipt, removes stale files and receipt-owned skills no longer present in the manifest, and writes a new receipt with the installed version. All destinations are committed as one transaction; an error restores the previous installation.

To replace a colliding path that has no valid collection receipt, inspect it first and use both explicit switches:

```powershell
.\scripts\install-skills.ps1 -Target Codex -Scope Project -ProjectRoot C:\src\my-project -Overwrite -ForceOverwriteUnmanaged
```

Version 1.0.0 moved Antigravity user installs from `.gemini/antigravity/skills` to the [current global location](https://codelabs.developers.google.com/getting-started-with-antigravity-skills), `.gemini/config/skills`. Re-running an existing managed Antigravity or Universal user installation with `-Overwrite` migrates only the skill directories listed in its legacy receipt and preserves unrelated directories.

## Uninstall

Preview or remove a receipt-managed installation:

```powershell
.\scripts\uninstall-skills.ps1 -Target Universal -Scope User -WhatIf
.\scripts\uninstall-skills.ps1 -Target Universal -Scope User
```

Project scope accepts the same `-ProjectRoot` argument as the installer. The uninstaller refuses malformed receipts, removes only paths named by a valid collection receipt, preserves unrelated skills, and rolls back if it cannot move every managed path into quarantine.

The scheduled `consumer-smoke.yml` workflow installs the latest Codex, Claude Code, OpenCode stable/V2, and Antigravity CLIs in isolated jobs. It verifies supported discovery layouts and runs each CLI's version check; Claude additionally validates the installed plugin in strict mode.

## Add project-specific rules

Do not copy repository architecture or business rules into these shared skills. A consuming repository should define at least:

- where source and tests live;
- supported build, lint, format, and test commands;
- architecture and dependency boundaries;
- security and data-handling constraints;
- mutation and publication approval rules.

## Contributing

See `CONTRIBUTING.md` for how to add or change a skill, and `CHANGELOG.md` for release history.

## Project site

The static landing page lives in `site/`, with a searchable skill catalog and a copyable installation
command builder. It has no runtime dependencies, tracking, or external font requests. Core content
and installation instructions remain available without JavaScript.

Preview it with `python -m http.server 8766 --directory site`. Browser checks verify responsive layout,
catalog parity with `skillset.json`, repository links, keyboard access and installation controls:

```sh
python -m pip install playwright==1.62.0
python -m playwright install chromium
python scripts/test-site.py
```

GitHub Pages must use **GitHub Actions** as its source in repository Settings → Pages. The
`Project site` workflow checks pull requests and deploys changes from `main` only after browser
checks pass. The public URL is `https://vannt-dev.github.io/ai-engineering-skills/`.
