---
type: llm
weight: 1
---

The response passes when it:

- explicitly applies both Dart/Flutter and database engineering concerns;
- addresses widget lifecycle, disposal, and checking that context/state is still mounted after an await;
- addresses query parameterization, and transaction or concurrency behavior where relevant. Migration compatibility is required only if the plan changes the schema; the feature as described does not need a schema change;
- distinguishes client, API, and database boundaries instead of treating the feature as one undifferentiated change;
- includes focused tests for the screen's states (loading, loaded, error, refresh after the dialog) and a check that what the API returns after an edit is what the screen shows. Because the feature changes no API or schema, running the API's existing tests or testing against a test API meets the persistence part; a new database test is not required.
