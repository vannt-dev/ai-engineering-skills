# Changelog

All notable changes to this skill collection are documented in this file.
Versioning follows semver against `skillset.json`'s `version` field:

- **patch** — wording/documentation fixes with no schema or layout change.
- **minor** — new skill added, or new optional metadata/target support.
- **major** — breaking change to `skillset.json` schema, canonical frontmatter, or install layout.

## Unreleased

- Fixed registry metadata validation to reject explicit null lists, uppercase tags, and tags longer than the schema's 32-character limit; added regression fixtures.
- Added optional machine-readable registry metadata to `skillset.json`: per-skill `appliesTo` globs and `tags`. Harnesses such as Junto use them to select a small, predictable set of skills for the files that changed instead of loading every skill. The metadata lives in the manifest because canonical `SKILL.md` frontmatter only allows `name` and `description`.
- Extended `skillset.schema.json` and `validate-skills.ps1` to validate `appliesTo` and `tags`.
- `review-code` now says how to review when the harness supplies a resolved file list, requirement background, or review-tool output.

## 1.0.0 — 2026-09-09

- Updated Antigravity user installation to the current global skills location, `~/.gemini/config/skills`; project installation remains under `.agents/skills`.
- Hardened `-Overwrite` so paths without a valid collection receipt require the additional `-ForceOverwriteUnmanaged` switch.
- Fixed `implement-change` stack routing to include `dart-engineering`, and added validation that keeps its explicit stack inventory synchronized with `skillset.json`.
- Strengthened validation for full semantic versions, description length, OpenAI interface metadata nesting, missing JSON properties, and multi-error reporting.
- Expanded installer and validator coverage from 13 to 21 functional tests, including negative fixtures, legacy Antigravity migration, receipt ownership boundaries, and optional Claude CLI plugin validation.
- Documented OpenCode V2 recursive discovery and precedence behavior for Universal installations.
- Pinned the GitHub Actions checkout dependency to the v4.4.0 commit digest.
- Made installation transactional across destinations with pre-staging, same-volume backups, automatic rollback, and cleanup of receipt-owned skills removed from the current manifest.
- Added a receipt-scoped transactional uninstaller with `-WhatIf` support and malformed-receipt refusal.
- Added published JSON Schemas for the collection manifest, installation receipt, and Codex/Claude plugin metadata.
- Added four behavioral eval cases, dependency-free fixture validation, and a cost-capped Claude CLI eval runner.
- Added scheduled/manual consumer smoke CI for Codex, Claude Code, OpenCode stable/V2, and Antigravity.

## 0.4.0 — 2026-09-06

- Added the `dart-engineering` stack skill: null-safety soundness, Flutter widget lifecycle and disposal, `BuildContext`-across-`await` safety, generated-file handling, and platform-channel contract guidance.

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
