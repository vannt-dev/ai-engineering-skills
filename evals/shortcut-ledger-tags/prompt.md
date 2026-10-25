We release next week. What did we leave for later in this repository? These are all of its files with comments, in full; this workspace holds no copy of them, so work from the text below. Line numbers start at 1 on the first line of each file.

`README.md`

```markdown
# ledger-sync

Imports customer ledgers and serves a status page.

## Capacity

Runs as one instance. Nightly imports reach 8,000 rows today, and the largest customer sends 30,000 rows in one file. API clients send up to 50 requests per second at peak.
```

`src/importer.py`

```python
import csv

# shortcut: validates rows one at a time, batch it once a file passes 10,000 rows
def load(path):
    with open(path, newline="") as handle:
        return [validate(row) for row in csv.DictReader(handle)]
```

`src/limits.ts`

```ts
// shortcut: in-memory rate limiter, move it to Redis when we run more than one instance
const hits = new Map<string, number>();
```

`db/report.sql`

```sql
-- shortcut: full table scan on orders
SELECT customer_id, SUM(total) FROM orders GROUP BY customer_id;
```

`config/app.ini`

```ini
[sync]
; shortcut: retry count hard-coded to 3
retries = 3
```

`web/status.html`

```html
<!-- shortcut: polls every 2 seconds, switch to server-sent events above 20 requests per second -->
<div id="status"></div>
```

`src/keys.ts`

```ts
// shortcut: Ctrl+K opens the command palette
export const PALETTE_KEY = "Ctrl+K";
```

`tests/test_parser.py`

```python
SAMPLE = "# shortcut: not a real marker, only parser input"


def test_parser_ignores_markers_in_strings():
    assert parse(SAMPLE) == []
```

`docs/conventions.md`

```markdown
Mark a deliberate shortcut with a comment of the form `shortcut: <the limit>, <when to upgrade>`.
```
