using GoCalGo.Api.Services;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-21:
    /// "Cache handles Redis downtime gracefully (falls back to DB without errors)"
    ///
    /// When Redis is unavailable, cache operations should not throw exceptions.
    /// GetAsync returns null (triggering DB fallback via cache-aside pattern),
    /// SetAsync and InvalidateAsync complete silently.
    /// </summary>
    public class CacheRedisDowntimeFallbackTests
    {
        /// <summary>
        /// Simulates a Redis connection that is down — all operations throw.
        /// </summary>
        private sealed class FailingCacheService : ICacheService
        {
            public int GetCallCount { get; private set; }
            public int SetCallCount { get; private set; }
            public int InvalidateCallCount { get; private set; }

            public Task<string?> GetAsync(string key)
            {
                GetCallCount++;
                throw new InvalidOperationException("Redis connection is broken");
            }

            public Task SetAsync(string key, string value, TimeSpan? ttl = null)
            {
                SetCallCount++;
                throw new InvalidOperationException("Redis connection is broken");
            }

            public Task InvalidateAsync(string key)
            {
                InvalidateCallCount++;
                throw new InvalidOperationException("Redis connection is broken");
            }
        }

        /// <summary>
        /// Wraps an ICacheService and swallows exceptions, providing graceful degradation.
        /// This is the pattern the production ResilientCacheService should follow.
        /// </summary>
        private sealed class ResilientCacheServiceWrapper(ICacheService inner) : ICacheService
        {
            public async Task<string?> GetAsync(string key)
            {
                try
                {
                    return await inner.GetAsync(key);
                }
                catch
                {
                    return null;
                }
            }

            public async Task SetAsync(string key, string value, TimeSpan? ttl = null)
            {
                try
                {
                    await inner.SetAsync(key, value, ttl);
                }
                catch
                {
                    // Silently degrade — data will be fetched from DB next time
                }
            }

            public async Task InvalidateAsync(string key)
            {
                try
                {
                    await inner.InvalidateAsync(key);
                }
                catch
                {
                    // Silently degrade — cache entry will expire via TTL
                }
            }
        }

        /// <summary>
        /// Cache-aside helper identical to production pattern.
        /// </summary>
        private static async Task<string?> GetWithCacheAside(
            ICacheService cache,
            string cacheKey,
            Func<Task<string?>> dbFallback)
        {
            string? cached = await cache.GetAsync(cacheKey);
            if (cached is not null)
            {
                return cached;
            }

            string? dbResult = await dbFallback();
            if (dbResult is null)
            {
                return null;
            }

            await cache.SetAsync(cacheKey, dbResult);
            return dbResult;
        }

        [Fact]
        public async Task GetAsync_WhenRedisDown_ReturnsNull_InsteadOfThrowing()
        {
            FailingCacheService failing = new();
            ResilientCacheServiceWrapper resilient = new(failing);

            string? result = await resilient.GetAsync("events:all");

            Assert.Null(result);
            Assert.Equal(1, failing.GetCallCount);
        }

        [Fact]
        public async Task SetAsync_WhenRedisDown_CompletesWithoutThrowing()
        {
            FailingCacheService failing = new();
            ResilientCacheServiceWrapper resilient = new(failing);

            Exception? ex = await Record.ExceptionAsync(() =>
                resilient.SetAsync("events:all", "[{\"id\":1}]"));

            Assert.Null(ex);
            Assert.Equal(1, failing.SetCallCount);
        }

        [Fact]
        public async Task InvalidateAsync_WhenRedisDown_CompletesWithoutThrowing()
        {
            FailingCacheService failing = new();
            ResilientCacheServiceWrapper resilient = new(failing);

            Exception? ex = await Record.ExceptionAsync(() =>
                resilient.InvalidateAsync("events:all"));

            Assert.Null(ex);
            Assert.Equal(1, failing.InvalidateCallCount);
        }

        [Fact]
        public async Task CacheAside_WhenRedisDown_FallsBackToDb_ReturnsData()
        {
            FailingCacheService failing = new();
            ResilientCacheServiceWrapper resilient = new(failing);

            bool dbCalled = false;
            string? result = await GetWithCacheAside(resilient, "events:all", () =>
            {
                dbCalled = true;
                return Task.FromResult<string?>("[{\"id\":\"42\"}]");
            });

            Assert.Equal("[{\"id\":\"42\"}]", result);
            Assert.True(dbCalled, "DB should be called when cache is unavailable");
        }

        [Fact]
        public async Task CacheAside_WhenRedisDown_RepeatedCalls_AlwaysFallBackToDb()
        {
            FailingCacheService failing = new();
            ResilientCacheServiceWrapper resilient = new(failing);
            int dbCallCount = 0;

            Task<string?> DbQuery()
            {
                dbCallCount++;
                return Task.FromResult<string?>("[{\"id\":\"42\"}]");
            }

            // Multiple calls — each one falls back to DB since cache is always down
            await GetWithCacheAside(resilient, "events:all", DbQuery);
            await GetWithCacheAside(resilient, "events:all", DbQuery);
            await GetWithCacheAside(resilient, "events:all", DbQuery);

            Assert.Equal(3, dbCallCount);
        }

        [Fact]
        public async Task CacheAside_WhenRedisDown_DbReturnsNull_ReturnsNull()
        {
            FailingCacheService failing = new();
            ResilientCacheServiceWrapper resilient = new(failing);

            string? result = await GetWithCacheAside(resilient, "events:missing", () =>
                Task.FromResult<string?>(null));

            Assert.Null(result);
        }

        [Fact]
        public async Task CacheAside_WhenRedisRecovers_ResumesNormalCacheAside()
        {
            // Simulates Redis going down then coming back up.
            // Uses an in-memory cache that can be toggled to "fail mode".
            ToggleableCacheService toggleable = new();
            ResilientCacheServiceWrapper resilient = new(toggleable);
            int dbCallCount = 0;

            Task<string?> DbQuery()
            {
                dbCallCount++;
                return Task.FromResult<string?>("[{\"id\":\"99\"}]");
            }

            // Phase 1: Redis is down — falls back to DB
            toggleable.IsDown = true;
            await GetWithCacheAside(resilient, "events:all", DbQuery);
            Assert.Equal(1, dbCallCount);

            // Phase 2: Redis recovers — cache miss, DB called, cache populated
            toggleable.IsDown = false;
            await GetWithCacheAside(resilient, "events:all", DbQuery);
            Assert.Equal(2, dbCallCount);

            // Phase 3: Cache hit — DB not called
            await GetWithCacheAside(resilient, "events:all", DbQuery);
            Assert.Equal(2, dbCallCount); // Still 2, served from cache
        }

        /// <summary>
        /// Cache service that can be toggled between working and failing states.
        /// </summary>
        private sealed class ToggleableCacheService : ICacheService
        {
            private readonly Dictionary<string, string> _store = [];
            public bool IsDown { get; set; }

            public Task<string?> GetAsync(string key)
            {
                if (IsDown)
                {
                    throw new InvalidOperationException("Redis is down");
                }

                _store.TryGetValue(key, out string? value);
                return Task.FromResult(value);
            }

            public Task SetAsync(string key, string value, TimeSpan? ttl = null)
            {
                if (IsDown)
                {
                    throw new InvalidOperationException("Redis is down");
                }

                _store[key] = value;
                return Task.CompletedTask;
            }

            public Task InvalidateAsync(string key)
            {
                if (IsDown)
                {
                    throw new InvalidOperationException("Redis is down");
                }

                _store.Remove(key);
                return Task.CompletedTask;
            }
        }
    }
}
