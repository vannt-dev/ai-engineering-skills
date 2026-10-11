---
name: preserve-comments
description: Keep existing comments, documentation blocks, and the blank-line layout around them intact while editing code in any language. Use on every edit, refactor, or configuration change that touches commented code, and when a user reports that comments were removed; do not use to keep a comment that a required change has made false.
---

# Preserve Comments

Comments carry what the code cannot: why a block exists, what a warning protects, how a section is organized. A comment removed next to a line that changed is lost context nobody asked to lose.

## Authority

Applies inside whatever change is already authorized. It grants no permission to edit files, and none to rewrite comments outside the lines the task changes.

## Workflow

1. Before editing, note the comments in and around the target: line and block comments, documentation comments, section headers above groups of statements, and commented-out configuration.
2. Change only what the task needs. Leave the surrounding comments, their wording, and the blank lines that separate sections exactly as they are, even when the code line beside them changes.
3. When a required change makes a comment false, update that comment in place so it describes the code as it now is. Do not delete it silently and do not leave it wrong.
4. When code moves, move its comments with it. When the task requires deleting code, delete the comments that described only that code, and nothing else.
5. Add a comment only where it helps the requested change, written to describe what the code means now. Do not replace an existing comment to make room for a new one.
6. Before reporting completion, compare the diff with step 1. Every removed comment line must trace to a required change; restore the ones that do not.

Do not remove comments as tidying, simplifying, or modernizing. Do not drop them when regenerating a file or rewriting a block wholesale. Do not translate or reword them unless asked. Repository instructions on comment language and documentation style override these defaults.

## Output

List each comment that was changed or removed and the required change behind it. Say so when none were.
