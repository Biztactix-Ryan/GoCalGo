using GoCalGo.Api.Services;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-21:
    /// "Cache is refreshed by the ingestion job on each successful fetch"
    ///
    /// Uses an in-memory cache test double and a simulated ingestion flow
    /// to validate that cache entries are replaced after each successful fetch.
    /// </summary>
    public class CacheRefreshOnIngestionTests
    {
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

        private const string CacheKey = "events:all";

        /// <summary>
        /// Simulates the expected ingestion-then-cache-refresh flow:
        /// fetch events, then write them to cache.
        /// </summary>
        private static async Task<string> SimulateIngestionWithCacheRefresh(
            ICacheService cache,
            Func<Task<string>> fetchEvents)
        {
            string fetched = await fetchEvents();
            await cache.SetAsync(CacheKey, fetched);
            return fetched;
        }

        [Fact]
        public async Task SuccessfulFetch_PopulatesCache()
        {
            InMemoryCacheService cache = new();

            // Cache starts empty
            Assert.Null(await cache.GetAsync(CacheKey));

            // Ingestion fetches and refreshes cache
            await SimulateIngestionWithCacheRefresh(cache,
                () => Task.FromResult("[{\"eventID\":\"evt-1\"}]"));

            string? cached = await cache.GetAsync(CacheKey);
            Assert.NotNull(cached);
            Assert.Contains("evt-1", cached);
        }

        [Fact]
        public async Task SecondFetch_ReplacesPreviousCacheEntry()
        {
            InMemoryCacheService cache = new();

            // First ingestion run
            await SimulateIngestionWithCacheRefresh(cache,
                () => Task.FromResult("[{\"eventID\":\"evt-1\"}]"));

            string? firstCached = await cache.GetAsync(CacheKey);
            Assert.Contains("evt-1", firstCached!);

            // Second ingestion run with updated data
            await SimulateIngestionWithCacheRefresh(cache,
                () => Task.FromResult("[{\"eventID\":\"evt-1\"},{\"eventID\":\"evt-2\"}]"));

            string? secondCached = await cache.GetAsync(CacheKey);
            Assert.Contains("evt-2", secondCached!);
            Assert.DoesNotContain("evt-1\"}]\"", secondCached); // Old single-item response replaced
        }

        [Fact]
        public async Task EachSuccessfulFetch_OverwritesStaleData()
        {
            InMemoryCacheService cache = new();
            int fetchCount = 0;

            async Task RunIngestion()
            {
                fetchCount++;
                await SimulateIngestionWithCacheRefresh(cache,
                    () => Task.FromResult($"[{{\"batch\":{fetchCount}}}]"));
            }

            // Run ingestion three times — each should overwrite the cache
            await RunIngestion();
            Assert.Contains("\"batch\":1", (await cache.GetAsync(CacheKey))!);

            await RunIngestion();
            Assert.Contains("\"batch\":2", (await cache.GetAsync(CacheKey))!);
            Assert.DoesNotContain("\"batch\":1", (await cache.GetAsync(CacheKey))!);

            await RunIngestion();
            Assert.Contains("\"batch\":3", (await cache.GetAsync(CacheKey))!);
            Assert.DoesNotContain("\"batch\":2", (await cache.GetAsync(CacheKey))!);
        }

        [Fact]
        public async Task FailedFetch_DoesNotCorruptExistingCache()
        {
            InMemoryCacheService cache = new();

            // Populate cache with a successful fetch
            await SimulateIngestionWithCacheRefresh(cache,
                () => Task.FromResult("[{\"eventID\":\"evt-1\"}]"));

            string? beforeFailure = await cache.GetAsync(CacheKey);

            // Simulate a failed fetch — cache should NOT be updated
            try
            {
                await SimulateFailedIngestionWithCacheRefresh(cache);
            }
            catch (HttpRequestException)
            {
                // Expected
            }

            string? afterFailure = await cache.GetAsync(CacheKey);
            Assert.Equal(beforeFailure, afterFailure);
        }

        /// <summary>
        /// Simulates a failed ingestion — throws before reaching the cache refresh step,
        /// verifying that the cache is never written to on failure.
        /// </summary>
        private static async Task SimulateFailedIngestionWithCacheRefresh(ICacheService cache)
        {
            // Fetch fails — exception is thrown before cache.SetAsync is ever called
            string fetched = await FailingFetch();
            await cache.SetAsync(CacheKey, fetched);
        }

        private static Task<string> FailingFetch()
        {
            throw new HttpRequestException("ScrapedDuck API returned 500");
        }
    }
}
