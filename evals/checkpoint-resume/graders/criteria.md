---
type: llm
weight: 1
---

The workspace is empty by design, so nothing can actually be run. The response passes when the procedure it describes:

- reads the existing handoff before editing;
- checks repository status, diffs, and relevant tests rather than trusting the handoff blindly;
- preserves unrelated user changes and identifies stale assumptions;
- continues from verified state instead of restarting completed work;
- writes an updated structured handoff with status, decisions, verification, and next steps if work remains unfinished.
