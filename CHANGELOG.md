# Changelog

All notable changes to this skill collection are documented in this file.
Versioning follows semver against `skillset.json`'s `version` field:

- **patch** — wording/documentation fixes with no schema or layout change.
- **minor** — new skill added, or new optional metadata/target support.
- **major** — breaking change to `skillset.json` schema, canonical frontmatter, or install layout.

## 0.3.0 — 2026-09-06

- Added the `checkpoint-progress` workflow skill: teaches any agent to check for an existing handoff note before resuming multi-session work, and to write a structured, platform-agnostic one (`docs/handoff/<topic>-<date>.md`) before a session ends with work in flight, runs low on context, or hands off to a different agent or tool.

## 0.2.0 — 2026-09-06

- Rewrote `scripts/install-skills.ps1`: preflight collision detection across all planned destinations before any copy, `-Overwrite` now replaces managed skill directories wholesale (removing stale files) instead of merging, installer runs the validator before installing, and every install writes a `.ai-engineering-skills.receipt.json` with collection/version/target/scope/timestamp/skill list. Adds `-WhatIf` support.
- Rewrote `scripts/validate-skills.ps1` with a dependency-free YAML frontmatter parser: duplicate-field and duplicate-skill-name detection, folder-name-matches-`name` check, `skillset.json` category/semver validation, relative Markdown link checking (now skips fenced/inline code spans), and parsing of both plugin manifests. `agents/openai.yaml` is treated as optional Codex metadata rather than required.
- Added `scripts/test-tooling.ps1`, a functional test suite covering installer behavior across targets, scopes, collisions, `-Overwrite` cleanup, non-collection-skill preservation, and `-WhatIf`.
- Added the `implement-change` workflow skill.
- Added `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` native plugin manifests.
- Added `.github/workflows/validate.yml` CI matrix (Ubuntu, Windows, macOS) running the validator and test suite on every push/PR.
- Added `.gitattributes` to normalize line endings to LF.
- Added `LICENSE` (MIT).

## 0.1.0 — 2026-09-05

- Initial cross-language engineering skill set: 7 workflow skills and 6 stack skills, `skillset.json` schema version 1, each skill shipping optional `agents/openai.yaml` Codex UI metadata.
