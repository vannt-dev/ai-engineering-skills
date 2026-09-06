---
name: checkpoint-progress
description: Preserve and resume multi-session or multi-agent work by checking for an existing handoff note before starting continuation work, and writing a structured, platform-agnostic one before a session ends with work still in flight. Use when picking up prior work, when a session must pause or hand off to a different agent, or when told context is running low; do not use for a task that starts and finishes within one session.
---

# Checkpoint Progress

Keep in-flight work resumable by anyone, on any platform, without relying on a single tool's built-in memory.

## Authority

Read-only with one exception: creating or updating the checkpoint file itself. Do not modify application source, configuration, tests, or other documentation as part of checkpointing.

## Workflow

1. Before re-deriving context for continuation work, look for an existing checkpoint (the repository's documented handoff location, or `docs/handoff/` if none is documented) and read it first.
2. Treat a checkpoint as a snapshot, not ground truth. Verify its claims against the current state of the repository (files, git history, running checks) before acting on them, and say so if reality has diverged.
3. Decide to write a checkpoint when a session must end with work still in flight, when told the context window is about to be summarized or exhausted, or when handing off to a different agent, tool, or platform.
4. Write the checkpoint as plain, git-tracked Markdown at `docs/handoff/<topic>-<date>.md` (or the repository's documented equivalent). Do not depend on a platform-specific memory or session feature — the note must be readable by any agent or human that opens the repository.
5. Structure the checkpoint around: the current source of truth and where it lives, what is done and verified (with how it was verified), what is in flight and exactly where, decisions already made and the reasoning behind them, the exact commands needed to re-verify state, an explicit list of what remains, and recommended next steps.
6. Mark plainly what is draft or staging versus canonical, and state anything that must not be treated as source of truth.
7. When resuming finds a checkpoint stale or superseded, update or replace it rather than leaving conflicting notes for the same effort.

Do not invent a new note location or format per platform, use a checkpoint as a substitute for verifying current state, leave a stale checkpoint uncorrected once work has diverged from it, or use checkpointing to justify skipping requirement analysis or planning.

## Output

Report the checkpoint file's path and either a summary of the resumed state (when reading one) or a summary of what was preserved and what remains (when writing one).
