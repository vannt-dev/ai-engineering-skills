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
- `challenge-review`
- `preserve-comments`
- `shortcut-ledger`

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
- the same skills go flat to `.claude/skills` for Claude Code, the only place Claude Code reads skills from (`.claude/skills/<skill>/SKILL.md`);
- user-scope Universal installation also installs the canonical skills into Antigravity's global directory at `.gemini/config/skills`.

[OpenCode](https://opencode.ai/docs/skills) reads both `.agents/skills` and `.claude/skills`. OpenCode 1.3.13 lists a skill found in both once, from `.agents/skills`, and [OpenCode V2](https://opencode.ai/v2/docs/skills) resolves such duplicates by source precedence. Use the direct `OpenCode` target when a single discovery source is required.

### Checked on real tools

What the collection was checked against on 23 October 2026, on Windows, during the 1.4.0 and 1.4.1 releases, with a project installation:

| Tool | Version | Skills read from | Skills found | A skill run |
| --- | --- | --- | --- | --- |
| Claude Code | 2.1.309 | `.claude/skills` | 18 of 18 | yes: `review-code`, `implement-change`, `challenge-review`, `shortcut-ledger` |
| Codex CLI | 0.164.0 | `.agents/skills` | not counted | yes: `shortcut-ledger` |
| OpenCode | 1.3.13 | `.agents/skills` (wins over `.claude/skills`) | 18, each once | not checked: the CLI ran no model |
| Antigravity CLI (`agy`) | 1.3.3 | `.agents/skills` | not listed at start | yes: `shortcut-ledger` |

"Skills found" is what the tool lists at start: the `skills` of Claude Code's init event, `opencode-cli debug skill` for OpenCode. `agy` lists no skills at start, and the Codex list was not counted; both were checked by use instead: each opened `shortcut-ledger` from `.agents/skills`, ran its search and gave the expected ledger row.

Up to 1.3.0 the installer put the Claude Code copy in a nested folder, `.claude/skills/ai-engineering-skills`, which Claude Code does not load. Run this version with `-Overwrite` to replace it with the flat layout.

The repository contains `.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` so it can also be packaged natively for Codex or Claude Code, and `.claude-plugin/marketplace.json` so Claude Code can [install it as a plugin](#install-in-claude-code) straight from GitHub.

## Validate

```powershell
.\scripts\validate-skills.ps1
.\scripts\validate-evals.ps1
.\scripts\test-tooling.ps1
```

The validators have no Python or third-party module dependency. They validate the intentionally restricted portable frontmatter schema, optional Codex UI metadata, reference links, collection manifest, duplicate names, plugin manifests, the Claude Code marketplace, published JSON Schemas, and behavioral eval fixture structure.

The `schemas/` directory publishes contracts for `skillset.json`, installation receipts, and both plugin metadata formats. Behavioral cases live under `evals/`. To execute them with Claude Code, an authenticated CLI, and an explicit cost ceiling:

```powershell
.\scripts\run-behavior-evals.ps1
.\scripts\run-behavior-evals.ps1 -Case "review-*" -JudgeModel sonnet -MaxCostUsd 2
```

With no arguments the script runs every case three times (`-Runs 3`), passes a case when two of its three runs pass (`-Threshold 0.6`), and stops at USD 6 (`-MaxCostUsd 6`). `-Case` takes a glob of case names; `-JudgeModel` names the model that grades the answers, which is the CLI's own choice otherwise.

The script calls `claude plugin eval`, which runs every case as a child of the signed-in CLI: with a claude.ai login the runs count against that plan's usage, with an API key they are billed. `-MaxCostUsd` caps the computed cost either way. Each case runs the same number of times without the collection, so the report shows what the skills change. The report goes to `evals/results/`, which git ignores. A grader file needs frontmatter with a `type` (`type: llm`); `validate-evals.ps1` checks it, because the eval run itself is not part of CI.

Three things to know when reading the results:

- One run of a case is not a verdict. Each answer is graded by three votes of the judge, and the default judge split its votes on about one grading in ten (5 of 48 in a run of the whole suite); at one run per case, a split decides the case. Three runs settle it, which is why they are the default: about USD 0.5 for a case, USD 4 for the eight cases. `-JudgeModel sonnet` gave no split vote in 18 gradings, at under two cents a grading, but it reads a criterion to the letter: it failed `read-only-boundary` three times of three over a side remark that carried no category label, until the criterion said that only the two named defects are judged on their labels. Write a criterion so that a strict reader and a lenient one reach the same verdict, and say what is not judged.

- A `skill-opened` grader (`type: tool_used`, `tool: Skill`) is an indicator, not part of the score: it shows whether the run opened a skill at all. A case in which no skill was opened compares the model with itself, so it cannot show what the collection adds.
- Each run works in an empty folder and cannot read files outside it. A skill's own `references/` files are out of reach there, although an installed copy reads them normally, so a case that depends on a reference file is weaker in the eval than in use.

To see what changed between two saved runs, for example before and after a skill edit, compare their reports. The comparison reads the saved `aggregate-result.json` files only; it runs no model and costs nothing:

```powershell
.\scripts\compare-eval-runs.ps1 -Baseline evals\results\2026-10-12T14-10-45-067Z -Candidate evals\results\2026-10-25T14-23-23-059Z
.\scripts\compare-eval-runs.ps1 -Baseline <older run> -Candidate <newer run> -Format Markdown
```

Each argument is a run folder under `evals/results/` or its `aggregate-result.json`. For every case the script prints the pass rate with and without the collection in both runs, the number of runs, and the change in cost (the case's runs and their grading), mean time and mean turns per run. The reports record no token counts, so there are none to compare. The cases come in this order:

| Status | Meaning |
| --- | --- |
| `regressed` | passed in the baseline, fails in the candidate |
| `worse` | lower pass rate, same verdict |
| `fixed` | failed in the baseline, passes in the candidate |
| `better` | higher pass rate, same verdict |
| `same` | same pass rate |
| `baseline-only`, `candidate-only` | the other run did not include the case, for example because of `-Case` |

A case passes when its pass rate with the collection reaches `-Threshold` (0.6, two runs of three, unless given). Both runs are judged on it rather than on the threshold each was run with, because a run made with `-Threshold 0` passes every case. `-Format Markdown` prints a table to paste into a pull request; `-Format Json` prints the same data for other tools. The exit code is 0 when no case regressed, 1 when at least one did, and 2 when a report cannot be read, so the script can gate a step that has both reports at hand. A drop that keeps the verdict, or a case missing from one run, does not fail it.

## Install

### Install in Claude Code

Claude Code installs the collection as a plugin from this repository's marketplace, with no clone
and no PowerShell. Inside Claude Code:

```text
/plugin marketplace add vannt-dev/ai-engineering-skills
/plugin install ai-engineering-skills@ai-engineering-skills
```

From a terminal, the same steps are `claude plugin marketplace add vannt-dev/ai-engineering-skills`
and `claude plugin install ai-engineering-skills@ai-engineering-skills`. On Claude Code 2.1.275 or
later one line does both:

```text
/plugin install ai-engineering-skills --marketplace vannt-dev/ai-engineering-skills
```

All 18 skills load as `ai-engineering-skills:<skill>`. `/plugin update ai-engineering-skills@ai-engineering-skills`
picks up a new release and `/plugin uninstall ai-engineering-skills@ai-engineering-skills` removes it.
If you installed the collection for Claude Code with the PowerShell installer before, remove that
copy with the uninstaller below so the skills are not loaded twice.

### Install with the PowerShell installer

Use the installer for Codex, OpenCode and Antigravity, for project scope, or for Claude Code
without a marketplace.

<!-- x-release-please-start-version -->

Download the [1.5.0 release][release]
and extract it, or check out the versioned source:

```bash
git clone --branch v1.5.0 --depth 1 https://github.com/vannt-dev/ai-engineering-skills.git
cd ai-engineering-skills
```

Run the commands below from the extracted collection directory. For an existing managed
installation, run the installer from this version with `-Overwrite`; preview first with `-WhatIf`.
The receipt records version 1.5.0. Unrelated skills are preserved.

[release]: https://github.com/vannt-dev/ai-engineering-skills/releases/tag/v1.5.0

<!-- x-release-please-end -->

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
