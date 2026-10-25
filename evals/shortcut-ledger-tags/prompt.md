We release next week. What did we leave for later in this repository? These are all of its files with comments, in full; this workspace holds no copy of them, so work from the text below. Line numbers start at 1 on the first line of each file.

`README.md`

```markdown
# order-sync

Imports the nightly order export into the warehouse database.

## Capacity

Runs as a single replica. Tonight's export is about 5,000 orders; after next week's launch we expect 50,000 orders per night.
```

`src/importer.py`

```python
import csv


def load_orders(path):
    # shortcut: reads the whole export into memory, stream it once a night passes 20,000 orders
    with open(path, newline="") as handle:
        return list(csv.DictReader(handle))
```

`src/notify.ts`

```ts
export async function notify(url: string, body: string): Promise<void> {
  // shortcut: retries three times in a tight loop with no backoff
  for (let attempt = 0; attempt < 3; attempt++) {
    const response = await fetch(url, { method: "POST", body });
    if (response.ok) return;
  }
  throw new Error(`notify failed: ${url}`);
}
```

`src/cache.go`

```go
package sync

// shortcut: in-process map cache, move it to Redis when we run more than one replica
var skuCache = map[string]int{}
```

`src/keys.ts`

```ts
// shortcut: Ctrl+S saves the draft; the binding lives in keymap.json
export const SAVE_KEY = "Ctrl+S";
```
