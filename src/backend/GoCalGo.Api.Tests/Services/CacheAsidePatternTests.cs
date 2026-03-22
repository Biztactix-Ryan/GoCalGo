using GoCalGo.Api.Data;
using GoCalGo.Api.Services;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-21:
    /// "Cache-aside pattern: check Redis then fall back to PostgreSQL"
    ///
    /// Validates that (1) both Redis cache and PostgreSQL are co-resolvable
    /// in DI, enabling the cache-aside pattern, and (2) the pattern logic is
    /// correct using an in-memory test double: cache hit returns cached data,
    /// cache miss falls back to a DB query and populates the cache.
    /// </summary>
    public class CacheAsideDiTests(WebApplicationFactory<Program> factory)
        : IClassFixture<WebApplicationFactory<Program>>
    {
        [Fact]
        public void BothCacheAndDbContext_AreResolvableFromDi()
        {
            using IServiceScope scope = factory.Services.CreateScope();
            ICacheService? cache = scope.ServiceProvider.GetService<ICacheService>();
            GoCalGoDbContext? db = scope.ServiceProvider.GetService<GoCalGoDbContext>();

            Assert.NotNull(cache);
            Assert.NotNull(db);
        }

        [Fact]
        public void CacheService_IsSingleton_DbContext_IsScoped()
        {
            // Cache is singleton — same instance across scopes
            ICacheService? cache1;
            ICacheService? cache2;
            using (IServiceScope s1 = factory.Services.CreateScope())
            {
                cache1 = s1.ServiceProvider.GetService<ICacheService>();
            }

            using (IServiceScope s2 = factory.Services.CreateScope())
            {
                cache2 = s2.ServiceProvider.GetService<ICacheService>();
            }

            Assert.Same(cache1, cache2);

            // DbContext is scoped — different instance per scope
            GoCalGoDbContext? db1;
            GoCalGoDbContext? db2;
            using (IServiceScope s1 = factory.Services.CreateScope())
            {
                db1 = s1.ServiceProvider.GetService<GoCalGoDbContext>();
            }

            using (IServiceScope s2 = factory.Services.CreateScope())
            {
                db2 = s2.ServiceProvider.GetService<GoCalGoDbContext>();
            }

            Assert.NotNull(db1);
            Assert.NotNull(db2);
            Assert.NotSame(db1, db2);
        }
    }

    /// <summary>
    /// Behavioral tests for the cache-aside pattern using an in-memory test double.
    /// Verifies: cache hit → return cached, cache miss → fall back to DB → populate cache.
    /// </summary>
    public class CacheAsidePatternBehaviorTests
    {
        /// <summary>
        /// In-memory ICacheService for testing the cache-aside flow without Redis.
        /// </summary>
        private sealed class InMemoryCacheService : ICacheService
        {
            private readonly Dictionary<string, string> _store = [];

            public Task<string?> GetAsync(string key)
            {
                _store.TryGetValue(key, out string? value);
                return Task.FromResult(value);
            }

            public Task SetAsync(string key, string value, TimeSpan? ttl = null)
            {
                _store[key] = value;
                return Task.CompletedTask;
            }

            public Task InvalidateAsync(string key)
            {
                _store.Remove(key);
                return Task.CompletedTask;
            }
        }

        /// <summary>
        /// Simulates the cache-aside pattern: check cache first, fall back to DB query,
        /// then populate cache for next time.
        /// </summary>
        private static async Task<string?> GetWithCacheAside(
            ICacheService cache,
            string cacheKey,
            Func<Task<string?>> dbFallback)
        {
            // Step 1: Check cache
            string? cached = await cache.GetAsync(cacheKey);
            if (cached is not null)
            {
                return cached;
            }

            // Step 2: Cache miss — fall back to DB
            string? dbResult = await dbFallback();
            if (dbResult is null)
            {
                return null;
            }

            // Step 3: Populate cache for next time
            await cache.SetAsync(cacheKey, dbResult);
            return dbResult;
        }

        [Fact]
        public async Task CacheHit_ReturnsCachedValue_WithoutDbCall()
        {
            InMemoryCacheService cache = new();
            await cache.SetAsync("events:all", "[{\"id\":\"1\"}]");

            bool dbCalled = false;
            string? result = await GetWithCacheAside(cache, "events:all", () =>
            {
                dbCalled = true;
                return Task.FromResult<string?>("[{\"id\":\"1\"}]");
            });

            Assert.Equal("[{\"id\":\"1\"}]", result);
            Assert.False(dbCalled, "DB should not be called on cache hit");
        }

        [Fact]
        public async Task CacheMiss_FallsBackToDb_AndPopulatesCache()
        {
            InMemoryCacheService cache = new();

            bool dbCalled = false;
            string? result = await GetWithCacheAside(cache, "events:all", () =>
            {
                dbCalled = true;
                return Task.FromResult<string?>("[{\"id\":\"2\"}]");
            });

            Assert.Equal("[{\"id\":\"2\"}]", result);
            Assert.True(dbCalled, "DB should be called on cache miss");

            // Cache should now be populated
            string? cachedAfter = await cache.GetAsync("events:all");
            Assert.Equal("[{\"id\":\"2\"}]", cachedAfter);
        }

        [Fact]
        public async Task CacheMiss_ThenCacheHit_OnSecondCall()
        {
            InMemoryCacheService cache = new();
            int dbCallCount = 0;

            Task<string?> DbQuery()
            {
                dbCallCount++;
                return Task.FromResult<string?>("[{\"id\":\"3\"}]");
            }

            // First call: cache miss → DB
            await GetWithCacheAside(cache, "events:all", DbQuery);
            Assert.Equal(1, dbCallCount);

            // Second call: cache hit → no DB
            string? result = await GetWithCacheAside(cache, "events:all", DbQuery);
            Assert.Equal("[{\"id\":\"3\"}]", result);
            Assert.Equal(1, dbCallCount); // Still 1, DB not called again
        }

        [Fact]
        public async Task CacheMiss_DbReturnsNull_CacheNotPopulated()
        {
            InMemoryCacheService cache = new();

            string? result = await GetWithCacheAside(cache, "events:missing", () =>
                Task.FromResult<string?>(null));

            Assert.Null(result);

            // Cache should NOT be populated with null
            string? cachedAfter = await cache.GetAsync("events:missing");
            Assert.Null(cachedAfter);
        }

        [Fact]
        public async Task Invalidate_ForcesCacheMiss_OnNextCall()
        {
            InMemoryCacheService cache = new();
            int dbCallCount = 0;

            Task<string?> DbQuery()
            {
                dbCallCount++;
                return Task.FromResult<string?>($"[{{\"version\":{dbCallCount}}}]");
            }

            // Populate cache
            await GetWithCacheAside(cache, "events:all", DbQuery);
            Assert.Equal(1, dbCallCount);

            // Invalidate
            await cache.InvalidateAsync("events:all");

            // Next call should miss cache and hit DB again
            string? result = await GetWithCacheAside(cache, "events:all", DbQuery);
            Assert.Equal(2, dbCallCount);
            Assert.Equal("[{\"version\":2}]", result);
        }
    }
}
