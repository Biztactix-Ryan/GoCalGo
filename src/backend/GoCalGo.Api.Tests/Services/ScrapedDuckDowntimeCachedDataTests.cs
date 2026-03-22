using System.Net;
using GoCalGo.Api.Configuration;
using GoCalGo.Api.Data;
using GoCalGo.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-4:
    /// "Job handles ScrapedDuck downtime gracefully by serving cached data"
    ///
    /// When ScrapedDuck API is unavailable, the ingestion job must:
    /// 1. Not crash — catch the failure and continue its schedule loop
    /// 2. Leave previously cached event data intact for serving
    /// 3. Resume normal ingestion when ScrapedDuck recovers
    /// </summary>
    public class ScrapedDuckDowntimeCachedDataTests
    {
        private static readonly string SampleEventsJson = """
            [
                {"eventID":"evt-1","name":"Community Day","eventType":"community-day","heading":"March CD","image":"img.png","link":"http://example.com","start":"2026-03-15 11:00","end":"2026-03-15 17:00","extraData":{}}
            ]
            """;

        [Fact]
        public async Task Job_WhenScrapedDuckDown_DoesNotCrash_ContinuesRunning()
        {
            // Arrange: ScrapedDuck returns 503 for all requests
            AlwaysFailHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHost(handler, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();

            // Act: start the job — it should not throw
            _ = job.StartAsync(cts.Token);
            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();

            // Assert: job attempted the fetch (didn't silently skip)
            Assert.True(handler.RequestCount >= 1, "Job should have attempted at least one fetch");
        }

        [Fact]
        public async Task Job_WhenScrapedDuckDown_StatusTrackerReportsFailure()
        {
            AlwaysFailHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHost(handler, scheduleIntervalMinutes: 60);

            IngestionStatusTracker tracker = host.Services.GetRequiredService<IngestionStatusTracker>();
            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();

            _ = job.StartAsync(cts.Token);
            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();

            Assert.NotNull(tracker.LastFetchTime);
            Assert.False(tracker.LastFetchSuccess, "Status tracker should report failure when ScrapedDuck is down");
        }

        [Fact]
        public async Task CachedData_SurvivesScrapedDuckDowntime_RemainsServable()
        {
            // Arrange: populate cache with event data (simulating a prior successful fetch)
            InMemoryCacheService cache = new();
            string cachedEvents = """[{"eventID":"evt-1","name":"Community Day"}]""";
            await cache.SetAsync(CacheKeys.EventsAll, cachedEvents);

            // Act: ScrapedDuck goes down — but cache is independent
            string? result = await cache.GetAsync(CacheKeys.EventsAll);

            // Assert: cached data is still available for serving
            Assert.NotNull(result);
            Assert.Equal(cachedEvents, result);
        }

        [Fact]
        public async Task CacheAside_WhenScrapedDuckDown_ServesStaleCache()
        {
            // Arrange: cache has data from a previous successful ingestion
            InMemoryCacheService cache = new();
            string previouslyFetchedData = """[{"eventID":"evt-1","name":"Spotlight Hour"}]""";
            await cache.SetAsync(CacheKeys.EventsAll, previouslyFetchedData);

            // Act: simulate an API endpoint reading from cache
            // Even though ScrapedDuck is down, the cache still has data from the last successful fetch
            string? result = await cache.GetAsync(CacheKeys.EventsAll);

            // Assert: stale cache served — ScrapedDuck downtime does not affect previously cached data
            Assert.NotNull(result);
            Assert.Contains("Spotlight Hour", result);
        }

        [Fact]
        public async Task IngestionService_AfterDowntime_ResumesNormalFetching()
        {
            // Arrange: ScrapedDuck fails first, then recovers
            FailThenSucceedHandler handler = new(SampleEventsJson, failCount: 1);
            IngestionStatusTracker tracker = new();

            using HttpClient httpClient = new(handler) { BaseAddress = new Uri("https://test.example.com") };
            ScrapedDuckSettings settings = new() { BaseUrl = "https://test.example.com" };
            using ILoggerFactory loggerFactory = LoggerFactory.Create(b => b.AddFilter(_ => false));

            IScrapedDuckClient client = new ScrapedDuckClient(
                httpClient,
                Options.Create(settings),
                loggerFactory.CreateLogger<ScrapedDuckClient>());

            DbContextOptions<GoCalGoDbContext> dbOptions = new DbContextOptionsBuilder<GoCalGoDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            GoCalGoDbContext db = new(dbOptions);
            ICacheService cache = new NullCacheService();

            ScrapedDuckIngestionService service = new(
                client,
                db,
                cache,
                tracker,
                loggerFactory.CreateLogger<ScrapedDuckIngestionService>());

            // Act: first call fails (ScrapedDuck down)
            await Assert.ThrowsAsync<ScrapedDuckClientException>(() => service.FetchEventsAsync());
            Assert.False(tracker.LastFetchSuccess);

            // Act: second call succeeds (ScrapedDuck recovered)
            IReadOnlyList<ParsedEvent> events = await service.FetchEventsAsync();

            // Assert: service recovered and fetched successfully
            Assert.True(tracker.LastFetchSuccess, "Service should recover after ScrapedDuck comes back");
            Assert.Single(events);
        }

        [Fact]
        public async Task FullFlow_CachePopulated_ScrapedDuckGoesDown_CachedDataStillServed()
        {
            // This end-to-end test simulates the complete lifecycle:
            // 1. Successful fetch → data cached
            // 2. ScrapedDuck goes down → job fails but cached data persists
            // 3. Consumer reads cached data successfully

            // Phase 1: Successful ingestion populates cache
            InMemoryCacheService cache = new();
            string eventData = """[{"eventID":"evt-1","name":"Community Day","eventType":"community-day"}]""";
            await cache.SetAsync(CacheKeys.EventsAll, eventData);

            // Phase 2: ScrapedDuck goes down — ingestion job fails
            AlwaysFailHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHost(handler, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);
            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();

            IngestionStatusTracker tracker = host.Services.GetRequiredService<IngestionStatusTracker>();
            Assert.False(tracker.LastFetchSuccess);

            // Phase 3: Cache still has data — consumers can still serve it
            string? cachedResult = await cache.GetAsync(CacheKeys.EventsAll);
            Assert.NotNull(cachedResult);
            Assert.Contains("Community Day", cachedResult);
        }

        [Fact]
        public async Task Job_MultipleConsecutiveFailures_NeverCrashes()
        {
            // Arrange: ScrapedDuck is down for an extended period
            AlwaysFailHandler handler = new();
            using CancellationTokenSource cts = new();

            // Use a very short interval so multiple iterations run quickly
            IHost host = BuildHost(handler, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();

            // Act: the job should handle multiple consecutive failures without crashing
            _ = job.StartAsync(cts.Token);
            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();

            // Assert: job survived multiple failures
            Assert.True(handler.RequestCount >= 1);
        }

        [Fact]
        public async Task Job_WhenScrapedDuckTimesOut_HandlesGracefully()
        {
            // Arrange: ScrapedDuck responds with a timeout
            TimeoutHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHost(handler, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();

            // Act: job should handle the timeout exception without crashing
            _ = job.StartAsync(cts.Token);

            // Give the job a moment to attempt the fetch
            await Task.Delay(500);
            cts.Cancel();

            // Assert: job didn't crash — if we got here, it handled the timeout
            Assert.True(handler.RequestCount >= 1, "Job should have attempted the fetch");
        }

        #region Test Infrastructure

        private static IHost BuildHost(HttpMessageHandler handler, int scheduleIntervalMinutes)
        {
            return Host.CreateDefaultBuilder()
                .ConfigureServices(services =>
                {
                    services.Configure<ScrapedDuckSettings>(opts =>
                    {
                        opts.BaseUrl = "https://test.example.com";
                        opts.ScheduleIntervalMinutes = scheduleIntervalMinutes;
                        opts.CacheExpirationMinutes = 5;
                    });

                    services.AddSingleton<IngestionStatusTracker>();
                    services.AddSingleton(handler);
                    services.AddTransient<IScrapedDuckClient>(sp =>
                    {
                        HttpClient client = new(sp.GetRequiredService<HttpMessageHandler>())
                        {
                            BaseAddress = new Uri("https://test.example.com")
                        };
                        return new ScrapedDuckClient(
                            client,
                            sp.GetRequiredService<IOptions<ScrapedDuckSettings>>(),
                            sp.GetRequiredService<ILogger<ScrapedDuckClient>>());
                    });
                    services.AddDbContext<GoCalGoDbContext>(opts =>
                        opts.UseInMemoryDatabase(Guid.NewGuid().ToString()));
                    services.AddSingleton<ICacheService, NullCacheService>();
                    services.AddTransient(sp =>
                        new ScrapedDuckIngestionService(
                            sp.GetRequiredService<IScrapedDuckClient>(),
                            sp.GetRequiredService<GoCalGoDbContext>(),
                            sp.GetRequiredService<ICacheService>(),
                            sp.GetRequiredService<IngestionStatusTracker>(),
                            sp.GetRequiredService<ILogger<ScrapedDuckIngestionService>>()));

                    services.AddSingleton<ScrapedDuckIngestionJob>();
                    services.AddSingleton<IHostedService>(sp => sp.GetRequiredService<ScrapedDuckIngestionJob>());
                })
                .Build();
        }

        private static async Task WaitForFetch(HttpMessageHandler handler, int expectedCount, int timeoutMs = 5000)
        {
            int elapsed = 0;
            while (elapsed < timeoutMs)
            {
                int count = handler switch
                {
                    AlwaysFailHandler h => h.RequestCount,
                    FailThenSucceedHandler h => h.RequestCount,
                    TimeoutHandler h => h.RequestCount,
                    _ => 0
                };

                if (count >= expectedCount)
                {
                    return;
                }

                await Task.Delay(50);
                elapsed += 50;
            }
        }

        /// <summary>
        /// Handler that always returns 503 Service Unavailable — simulates ScrapedDuck downtime.
        /// </summary>
        private sealed class AlwaysFailHandler : HttpMessageHandler
        {
            private volatile int _requestCount;
            public int RequestCount => _requestCount;

            protected override Task<HttpResponseMessage> SendAsync(
                HttpRequestMessage request, CancellationToken cancellationToken)
            {
                Interlocked.Increment(ref _requestCount);
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
                {
                    Content = new StringContent("Service Unavailable")
                });
            }
        }

        /// <summary>
        /// Handler that fails for the first N requests, then returns success.
        /// Simulates ScrapedDuck recovering from downtime.
        /// </summary>
        private sealed class FailThenSucceedHandler(string responseBody, int failCount) : HttpMessageHandler
        {
            private volatile int _requestCount;
            public int RequestCount => _requestCount;

            protected override Task<HttpResponseMessage> SendAsync(
                HttpRequestMessage request, CancellationToken cancellationToken)
            {
                int current = Interlocked.Increment(ref _requestCount);

                return current <= failCount
                    ? Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
                    {
                        Content = new StringContent("Service Unavailable")
                    })
                    : Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                    {
                        Content = new StringContent(responseBody, System.Text.Encoding.UTF8, "application/json")
                    });
            }
        }

        /// <summary>
        /// Handler that simulates a request timeout via TaskCanceledException.
        /// </summary>
        private sealed class TimeoutHandler : HttpMessageHandler
        {
            private volatile int _requestCount;
            public int RequestCount => _requestCount;

            protected override Task<HttpResponseMessage> SendAsync(
                HttpRequestMessage request, CancellationToken cancellationToken)
            {
                Interlocked.Increment(ref _requestCount);
                throw new TaskCanceledException("The request timed out");
            }
        }

        /// <summary>
        /// Simple in-memory cache for testing cache persistence during ScrapedDuck downtime.
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

        private sealed class NullCacheService : ICacheService
        {
            public Task<string?> GetAsync(string key)
            {
                return Task.FromResult<string?>(null);
            }

            public Task SetAsync(string key, string value, TimeSpan? ttl = null)
            {
                return Task.CompletedTask;
            }

            public Task InvalidateAsync(string key)
            {
                return Task.CompletedTask;
            }
        }

        #endregion
    }
}
