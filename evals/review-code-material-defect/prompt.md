Review this TypeScript change for material defects. Focus on correctness and actionable findings; do not rewrite the implementation unless needed to explain a fix.

```ts
export async function reserve(stock: Map<string, number>, sku: string, quantity: number) {
  const available = stock.get(sku) ?? 0;
  if (available < quantity) return false;
  await auditReservation(sku, quantity);
  stock.set(sku, available - quantity);
  return true;
}
```

This function can be called concurrently for the same `stock` map and SKU. `auditReservation` is an asynchronous network call.
