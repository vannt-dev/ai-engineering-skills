---
name: shortcut-ledger
description: List the deliberate shortcuts marked in a repository with `shortcut:` comments as one ledger of deferred work, and flag the ones that name no upgrade trigger or whose limit the expected load already crosses. Use when asked what was deferred, simplified, or left for later, for a list of shortcuts or technical debt, or before a release or an expected rise in load; read-only, it changes no code.
---

# Shortcut Ledger

A deliberate shortcut is fine while its limit holds. It turns into a defect when the limit is crossed and nobody remembers the shortcut was there. This skill collects every marked shortcut into one list, so "later" does not quietly become "never".

## Authority

Read-only. Search and report; do not edit code or comments. Write the ledger to a file only when the user asks for one, at the path they name.

## Convention

`implement-change` marks a shortcut with a one-line comment in the form `shortcut: <the limit>, <when to upgrade>`, for example `# shortcut: loads the whole file into memory, stream it once inputs pass 100 MB`. When the user or the repository instructions name a different marker word, search for that word instead.

## Workflow

1. Search tracked and untracked files, skipping what the ignore files exclude, for the marker after a comment prefix:
   `git grep --untracked -nE '(#|//|/\*|--|;|<!--) ?shortcut:'`
   Outside a git repository, run `rg -n` with the same pattern. Add the comment prefixes of any other language the repository uses.
2. Drop hits that are not deferrals, such as prose about keyboard shortcuts or documentation of this convention.
3. For each marker, take the limit and the upgrade trigger from the comment. Tag it `no-trigger` when it names no trigger or upgrade path: those are the ones that rot.
4. When the repository states its expected load (README, deployment configuration, capacity notes), tag `crossed` any marker whose limit that load already exceeds, and cite the evidence. Do not guess a load the repository does not state.
5. When the user asks for owners or age, add `git blame -L <line>,<line> -- <file>` for each row.

## Output

One row per marker, grouped by file:

`<file>:<line>: <what was simplified>. limit: <the limit>. upgrade: <the trigger>.` followed by any tags.

End with `<N> markers, <M> with no trigger, <K> crossed.` When nothing is found, say `No marked shortcuts.` and give the command that was run.
