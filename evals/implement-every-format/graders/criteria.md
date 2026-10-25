---
type: llm
weight: 1
---

The workspace is empty, so this case judges whether the change reaches every output format and every place that documents the options, not whether it runs.

The response passes when it:

- adds `--quiet` to the option parsing and to the `USAGE` string;
- says what `--quiet` does for each of `text`, `json`, and `sarif`, and on a run with no drift still writes a valid JSON document and a valid SARIF log (for example an empty `drift` array or empty `results`), or refuses or ignores `--quiet` for those formats with a stated reason; a change under which `--quiet` makes a clean JSON or SARIF run print nothing fails this criterion;
- keeps the existing behavior when drift is found and when `--quiet` is not given;
- adds a row for `--quiet` to the README options table;
- adds at least one test for the clean-run case under `--quiet`;
- does not claim to have run the tests or the CLI.
