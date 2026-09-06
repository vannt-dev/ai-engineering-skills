# Contributing

## Adding a skill

1. Create `skills/<skill-name>/SKILL.md` with only the portable `name` and `description` frontmatter fields. `name` must match the directory name and use lowercase letters, digits, and hyphens.
2. Write `description` so it states what the skill does and when to use it (and, where relevant, when not to). This is the only signal an agent has to pick the right skill.
3. Add the skill to `skillset.json` with a `category` of `workflow` or `stack`.
4. Optionally add `skills/<skill-name>/agents/openai.yaml` with `interface.display_name`, `interface.short_description`, and `interface.default_prompt` (the default prompt must reference the skill as `$<skill-name>`). This is Codex-specific UI metadata and is never required.
5. Run the checks below before opening a PR.

## Changing an existing skill

Keep changes scoped to the skill's own guidance. Do not introduce repository-specific architecture, business rules, or tooling assumptions into a canonical skill — those belong in a consuming repository's own project instructions.

## Required checks

```powershell
.\scripts\validate-skills.ps1
.\scripts\test-tooling.ps1
git diff --check
```

All three must pass with no errors before a change is committed. CI runs the same two scripts on Windows, Linux, and macOS.

## Versioning

Bump `version` in `skillset.json` (kept in sync with both plugin manifests) following semver:

- **patch** — wording or documentation fixes with no schema or layout change.
- **minor** — a new skill, or new optional metadata/target support.
- **major** — a breaking change to `skillset.json` schema, canonical frontmatter, or install layout.

Record the change in `CHANGELOG.md`.

## License decisions

This repository's license is decided by the repository owner. Do not add, change, or remove `LICENSE` without that explicit decision.
