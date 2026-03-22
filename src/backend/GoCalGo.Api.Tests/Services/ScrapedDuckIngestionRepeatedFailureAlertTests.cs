using System.Net;
using GoCalGo.Api.Configuration;
using GoCalGo.Api.Data;
using GoCalGo.Api.Services;
using GoCalGo.Api.Tests.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Serilog;
using Serilog.Formatting.Compact;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-36:
    /// "Ingestion job alerts on repeated failures (logged at Warning/Error level)"
    /// </summary>
    public class ScrapedDuckIngestionRepeatedFailureAlertTests
    {
        [Fact]
        public async Task Job_OnRepeatedFailures_LogsEachFailureAtErrorLevel()
        {
            StringWriter logOutput = new();
            AlwaysFailingHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 0);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 3);
            cts.Cancel();
            await job.StopAsync(CancellationToken.None);
            logOutput.Flush();

            string logs = logOutput.ToString();
            string[] lines = logs.Split('\n', StringSplitOptions.RemoveEmptyEntries);

            // Each failure should produce Error-level log entries
            int errorCount = lines.Count(line => line.Contains("\"@l\":\"Error\""));
            Assert.True(errorCount >= 3, $"Expected at least 3 Error-level log entries for 3 consecutive failures, got {errorCount}");
        }

        [Fact]
        public async Task Job_OnRepeatedFailures_LogsIterationFailedForEachFailure()
        {
            StringWriter logOutput = new();
            AlwaysFailingHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 0);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 2);
            cts.Cancel();
            await job.StopAsync(CancellationToken.None);
            logOutput.Flush();

            string logs = logOutput.ToString();
            string[] lines = logs.Split('\n', StringSplitOptions.RemoveEmptyEntries);

            int iterationFailedCount = lines.Count(line => line.Contains("ScrapedDuck ingestion job iteration failed"));
            Assert.True(iterationFailedCount >= 2, $"Expected at least 2 'iteration failed' messages, got {iterationFailedCount}");
        }

        [Fact]
        public async Task Job_OnRepeatedFailures_NeverLogsFailuresBelowWarningLevel()
        {
            StringWriter logOutput = new();
            AlwaysFailingHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();
            await job.StopAsync(CancellationToken.None);
            logOutput.Flush();

            string logs = logOutput.ToString();
            string[] lines = logs.Split('\n', StringSplitOptions.RemoveEmptyEntries);

            // Filter to lines that mention failure — they should all be Error or Warning level
            IEnumerable<string> failureLines = lines.Where(line =>
                line.Contains("failed", StringComparison.OrdinalIgnoreCase) ||
                line.Contains("Ingestion failed", StringComparison.OrdinalIgnoreCase));

            foreach (string line in failureLines)
            {
                // In compact JSON, @l is omitted for Information level. Error/Warning are explicit.
                // A failure log at Information level would NOT have @l set.
                bool hasExplicitLevel = line.Contains("\"@l\":\"Error\"") || line.Contains("\"@l\":\"Warning\"");
                Assert.True(hasExplicitLevel, $"Failure log should be at Warning or Error level, but was Information: {line}");
            }
        }

        [Fact]
        public async Task Job_OnRepeatedFailures_StatusTrackerReflectsFailureState()
        {
            AlwaysFailingHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, new StringWriter(), scheduleIntervalMinutes: 60);

            IngestionStatusTracker tracker = host.Services.GetRequiredService<IngestionStatusTracker>();
            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();

            Assert.False(tracker.LastFetchSuccess);
            Assert.NotNull(tracker.LastFetchTime);
        }

        [Fact]
        public async Task Job_OnRepeatedFailures_IncludesExceptionDetailsInLog()
        {
            StringWriter logOutput = new();
            AlwaysFailingHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();
            await job.StopAsync(CancellationToken.None);
            logOutput.Flush();

            string logs = logOutput.ToString();
            // Compact JSON includes exception info in @x field
            Assert.Contains("\"@x\"", logs);
        }

        [Fact]
        public async Task Job_ContinuesRunningAfterMultipleConsecutiveFailures()
        {
            FailThenSucceedHandler handler = new(failCount: 3);
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, new StringWriter(), scheduleIntervalMinutes: 0);

            IngestionStatusTracker tracker = host.Services.GetRequiredService<IngestionStatusTracker>();
            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            // Wait for the success iteration to complete by polling the tracker
            int elapsed = 0;
            while (elapsed < 10000 && tracker.LastFetchSuccess != true)
            {
                await Task.Delay(50);
                elapsed += 50;
            }
            cts.Cancel();

            Assert.True(tracker.LastFetchSuccess, "Job should recover and succeed after repeated failures");
            Assert.Equal(1, tracker.LastFetchEventCount);
        }

        [Fact]
        public async Task Job_OnRepeatedFailures_LogsIngestionFailedAtErrorLevel()
        {
            StringWriter logOutput = new();
            AlwaysFailingHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();
            await job.StopAsync(CancellationToken.None);
            logOutput.Flush();

            string logs = logOutput.ToString();
            // Verify both the service-level and job-level error logs appear for repeated failures
            Assert.Contains("Ingestion failed", logs);
            Assert.Contains("ScrapedDuck ingestion job iteration failed", logs);
            Assert.Contains("\"@l\":\"Error\"", logs);
        }

        private static IHost BuildHostWithLogging(HttpMessageHandler handler, StringWriter logOutput, int scheduleIntervalMinutes)
        {
            RenderedCompactJsonFormatter formatter = new();
            Serilog.Core.Logger serilogLogger = new LoggerConfiguration()
                .MinimumLevel.Debug()
                .WriteTo.Sink(new TextWriterSink(formatter, logOutput))
                .CreateLogger();

            return Host.CreateDefaultBuilder()
                .UseSerilog(serilogLogger)
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

        private static async Task WaitForFetch(HttpMessageHandler handler, int expectedCount, int timeoutMs = 10000)
        {
            int elapsed = 0;
            while (elapsed < timeoutMs)
            {
                int count = handler switch
                {
                    AlwaysFailingHandler h => h.RequestCount,
                    FailThenSucceedHandler h => h.RequestCount,
                    _ => 0
                };
                if (count >= expectedCount)
                {
                    break;
                }
                await Task.Delay(50);
                elapsed += 50;
            }
            // Allow time for the full pipeline (logging, status update) to complete
            await Task.Delay(300);
        }

        private sealed class AlwaysFailingHandler : HttpMessageHandler
        {
            private volatile int _requestCount;
            public int RequestCount => _requestCount;

            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            {
                Interlocked.Increment(ref _requestCount);
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent("Server Error")
                });
            }
        }

        private sealed class FailThenSucceedHandler(int failCount) : HttpMessageHandler
        {
            private static readonly string SampleEventsJson = """
                [
                    {"eventID":"evt-1","name":"Community Day","eventType":"community-day","heading":"March CD","image":"img.png","link":"http://example.com","start":"2026-03-15 11:00","end":"2026-03-15 17:00","extraData":{}}
                ]
                """;

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
                        Content = new StringContent(SampleEventsJson, System.Text.Encoding.UTF8, "application/json")
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
    }
}
