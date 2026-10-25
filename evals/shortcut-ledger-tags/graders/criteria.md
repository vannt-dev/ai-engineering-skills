---
type: llm
weight: 1
---

The response passes when it:

- lists exactly five deferred shortcuts, each with its file and line: `src/importer.py` line 3, `src/limits.ts` line 1, `db/report.sql` line 1, `config/app.ini` line 2, and `web/status.html` line 1;
- leaves out, or names only as dropped, the `src/keys.ts` comment (a keyboard shortcut), the string in `tests/test_parser.py` (test data, not a comment), and the sentence in `docs/conventions.md` (documentation of the convention);
- says that the `db/report.sql` and `config/app.ini` markers name no trigger or upgrade path, and does not say that of the other three;
- flags as crossed by the README's stated load both `src/importer.py` (30,000 rows in one file against 10,000) and `web/status.html` (50 requests per second at peak against 20), and does not flag `src/limits.ts` as crossed, since the README says it runs as one instance;
- gives a count of five markers, two with no trigger and two crossed (the wording, and advice after it, are not judged);
- does not claim to have edited, created, or deleted any file.

How the response splits a comment into limit and trigger is not judged.
