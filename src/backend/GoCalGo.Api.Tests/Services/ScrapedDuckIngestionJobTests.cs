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
    public class ScrapedDuckIngestionJobTests
    {
        private static readonly string SampleEventsJson = """
            [
                {"eventID":"evt-1","name":"Community Day","eventType":"community-day","heading":"March CD","image":"img.png","link":"http://example.com","start":"2026-03-15 11:00","end":"2026-03-15 17:00","extraData":{}}
            ]
            """;

        [Fact]
        public async Task Job_FetchesFromScrapedDuckApi_OnStart()
        {
            TrackingHttpHandler handler = new(SampleEventsJson);
            using CancellationTokenSource cts = new();
            IHost host = BuildHost(handler, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();

            Assert.True(handler.RequestCount >= 1, "Expected at least one fetch request");
            Assert.Contains("/data/events.json", handler.LastRequestUrl);
        }

        [Fact]
        public async Task Job_UsesConfigurableScheduleInterval()
        {
            TrackingHttpHandler handler = new(SampleEventsJson);
            using CancellationTokenSource cts = new();

            IHost host = BuildHost(handler, scheduleIntervalMinutes: 1);
            IOptions<ScrapedDuckSettings> settings = host.Services.GetRequiredService<IOptions<ScrapedDuckSettings>>();

            Assert.Equal(1, settings.Value.ScheduleIntervalMinutes);
        }

        [Fact]
        public async Task Job_ReadsScheduleIntervalFromConfiguration()
        {
            TrackingHttpHandler handler = new(SampleEventsJson);
            IHost host = BuildHost(handler, scheduleIntervalMinutes: 42);

            IOptions<ScrapedDuckSettings> settings = host.Services.GetRequiredService<IOptions<ScrapedDuckSettings>>();
            Assert.Equal(42, settings.Value.ScheduleIntervalMinutes);
        }

        [Fact]
        public void ScheduleIntervalMinutes_DefaultsTo15()
        {
            ScrapedDuckSettings settings = new();
            Assert.Equal(15, settings.ScheduleIntervalMinutes);
        }

        [Fact]
        public async Task Job_IsRegisteredAsHostedService()
        {
            TrackingHttpHandler handler = new(SampleEventsJson);
            IHost host = BuildHost(handler, scheduleIntervalMinutes: 60);

            IEnumerable<IHostedService> hostedServices = host.Services.GetServices<IHostedService>();
            Assert.Contains(hostedServices, s => s is ScrapedDuckIngestionJob);
        }

        [Fact]
        public async Task Job_ContinuesAfterFetchFailure()
        {
            FailThenSucceedHandler handler = new(SampleEventsJson, failCount: 1);
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithHandler(handler, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetchCount(handler, expectedCount: 1, timeoutMs: 5000);
            cts.Cancel();

            Assert.True(handler.RequestCount >= 1);
        }

        [Fact]
        public async Task Job_UpdatesIngestionStatusTracker()
        {
            TrackingHttpHandler handler = new(SampleEventsJson);
            using CancellationTokenSource cts = new();
            IHost host = BuildHost(handler, scheduleIntervalMinutes: 60);

            IngestionStatusTracker tracker = host.Services.GetRequiredService<IngestionStatusTracker>();
            Assert.Null(tracker.LastFetchTime);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();

            Assert.NotNull(tracker.LastFetchTime);
            Assert.True(tracker.LastFetchSuccess);
            Assert.Equal(1, tracker.LastFetchEventCount);
        }

        [Fact]
        public async Task Job_StopsGracefullyOnCancellation()
        {
            TrackingHttpHandler handler = new(SampleEventsJson);
            using CancellationTokenSource cts = new();
            IHost host = BuildHost(handler, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();

            await job.StopAsync(CancellationToken.None);
        }

        private static IHost BuildHost(TrackingHttpHandler handler, int scheduleIntervalMinutes)
        {
            return BuildHostWithHandler(handler, scheduleIntervalMinutes);
        }

        private static IHost BuildHostWithHandler(HttpMessageHandler handler, int scheduleIntervalMinutes)
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

        private static async Task WaitForFetch(TrackingHttpHandler handler, int expectedCount, int timeoutMs = 5000)
        {
            int elapsed = 0;
            while (handler.RequestCount < expectedCount && elapsed < timeoutMs)
            {
                await Task.Delay(50);
                elapsed += 50;
            }
        }

        private static async Task WaitForFetchCount(FailThenSucceedHandler handler, int expectedCount, int timeoutMs = 5000)
        {
            int elapsed = 0;
            while (handler.RequestCount < expectedCount && elapsed < timeoutMs)
            {
                await Task.Delay(50);
                elapsed += 50;
            }
        }

        private sealed class TrackingHttpHandler(string responseBody) : HttpMessageHandler
        {
            private volatile int _requestCount;

            public int RequestCount => _requestCount;
            public string? LastRequestUrl { get; private set; }

            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            {
                LastRequestUrl = request.RequestUri?.ToString();
                Interlocked.Increment(ref _requestCount);

                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(responseBody, System.Text.Encoding.UTF8, "application/json")
                });
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

        private sealed class FailThenSucceedHandler(string responseBody, int failCount) : HttpMessageHandler
        {
            private volatile int _requestCount;
            public int RequestCount => _requestCount;

            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            {
                int current = Interlocked.Increment(ref _requestCount);

                return current <= failCount
                    ? Task.FromResult(new HttpResponseMessage(HttpStatusCode.InternalServerError)
                    {
                        Content = new StringContent("Server Error")
                    })
                    : Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                    {
                        Content = new StringContent(responseBody, System.Text.Encoding.UTF8, "application/json")
                    });
            }
        }
    }
}
