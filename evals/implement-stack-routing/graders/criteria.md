---
type: llm
weight: 1
---

The response passes when it:

- explicitly applies both Dart/Flutter and database engineering concerns;
- addresses widget lifecycle, disposal, and checking that context/state is still mounted after an await;
- addresses query parameterization, and transaction or concurrency behavior where relevant. Migration compatibility is required only if the plan changes the schema; the feature as described does not need a schema change;
- distinguishes client, API, and database boundaries instead of treating the feature as one undifferentiated change;
- includes focused tests for UI state and persistence behavior.
