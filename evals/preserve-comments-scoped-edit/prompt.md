Change the cache registration in this file to use the real client, `RedisCache`, instead of the fake one. Show the resulting file.

```csharp
// --- Infrastructure -------------------------------------------------
// Redis (fake): swapped for the real client once the cluster is ready (OPS-212)
services.AddSingleton<ICache, FakeRedisCache>();

// Message bus: keep before the handlers, they resolve it in their constructors
services.AddSingleton<IBus, RabbitBus>();

// --- Handlers -------------------------------------------------------
services.AddScoped<OrderHandler>(); // scoped on purpose: holds a DbContext
```
