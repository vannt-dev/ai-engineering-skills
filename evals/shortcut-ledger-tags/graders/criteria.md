---
type: llm
weight: 1
---

The response passes when it:

- lists exactly three deferred shortcuts: the in-memory read in `src/importer.py` (line 5), the retry loop in `src/notify.ts` (line 2), and the in-process cache in `src/cache.go` (line 3), each with its file and line;
- leaves out the `src/keys.ts` comment, or names it only as dropped, because it describes a keyboard shortcut and not deferred work;
- for each of the three, says what was simplified and, where the comment gives one, when or how to upgrade it (how the response splits a comment into limit and trigger is not judged), and says that the `notify.ts` marker names no trigger or upgrade path;
- flags the `importer.py` shortcut as crossed by the expected load, citing the README's expected 50,000 orders per night against the 20,000 limit (saying that tonight's 5,000 is still under it is right, not a miss), and does not flag the cache as crossed, since the README says it runs as a single replica;
- gives a count of three markers, one with no trigger and one crossed (the wording, and advice after it, are not judged);
- does not claim to have edited, created, or deleted any file.
