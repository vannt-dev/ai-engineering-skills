Add a `--quiet` flag to this CLI so CI logs stay clean when there is no drift. These are all of the project's files that touch output or options, in full; this workspace holds no copy of them, so reply with the change as unified diffs against the text below.

`src/cli.ts`

```ts
import { parseArgs } from "node:util";
import { findDrift } from "./drift.js";
import { render, type Format } from "./report.js";

const USAGE = "usage: drift-check <spec> <routes-dir> [--format text|json|sarif] [--fail-on-drift]";

export async function main(argv: string[]): Promise<number> {
  const { values, positionals } = parseArgs({
    args: argv,
    allowPositionals: true,
    options: {
      format: { type: "string", default: "text" },
      "fail-on-drift": { type: "boolean", default: false },
      help: { type: "boolean", default: false },
    },
  });
  if (values.help || positionals.length !== 2) {
    console.log(USAGE);
    return values.help ? 0 : 2;
  }
  const drift = await findDrift(positionals[0], positionals[1]);
  process.stdout.write(render(drift, values.format as Format));
  return values["fail-on-drift"] && drift.length > 0 ? 1 : 0;
}
```

`src/report.ts`

```ts
export type Format = "text" | "json" | "sarif";
export interface Drift {
  route: string;
  kind: "missing" | "undocumented";
}

export function render(drift: Drift[], format: Format): string {
  switch (format) {
    case "json":
      return JSON.stringify({ drift }, null, 2) + "\n";
    case "sarif":
      return JSON.stringify(toSarif(drift), null, 2) + "\n";
    default:
      if (drift.length === 0) return "No drift found.\n";
      return drift.map((d) => `${d.kind}: ${d.route}`).join("\n") + "\n";
  }
}

function toSarif(drift: Drift[]) {
  return {
    version: "2.1.0",
    runs: [
      {
        tool: { driver: { name: "drift-check" } },
        results: drift.map((d) => ({ ruleId: d.kind, message: { text: d.route } })),
      },
    ],
  };
}
```

`test/report.test.ts`

```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { render } from "../src/report.js";

test("text lists each drift", () => {
  assert.equal(render([{ route: "GET /a", kind: "missing" }], "text"), "missing: GET /a\n");
});
```

`README.md` (the options section)

```markdown
## Options

| Option | Meaning |
| --- | --- |
| `--format text\|json\|sarif` | Output format; `text` by default. |
| `--fail-on-drift` | Exit with code 1 when drift is found. |
```
