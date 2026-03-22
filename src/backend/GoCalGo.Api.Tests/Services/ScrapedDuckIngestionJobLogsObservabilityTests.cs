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
    /// Verifies acceptance criterion for story US-GCG-4:
    /// "Job logs success/failure for observability"
    /// </summary>
    public class ScrapedDuckIngestionJobLogsObservabilityTests
    {
        private static readonly string SampleEventsJson = """
            [
                {"eventID":"evt-1","name":"Community Day","eventType":"community-day","heading":"March CD","image":"img.png","link":"http://example.com","start":"2026-03-15 11:00","end":"2026-03-15 17:00","extraData":{}}
            ]
            """;

        [Fact]
        public async Task Job_LogsStartMessage_WithScheduleInterval()
        {
            StringWriter logOutput = new();
            TrackingHttpHandler handler = new(SampleEventsJson);
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 15);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();
            logOutput.Flush();

            string logs = logOutput.ToString();
            Assert.Contains("ScrapedDuck ingestion job started", logs);
            Assert.Contains("15", logs);
        }

        [Fact]
        public async Task Job_OnSuccessfulFetch_LogsCompletionWithEventCount()
        {
            StringWriter logOutput = new();
            TrackingHttpHandler handler = new(SampleEventsJson);
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();
            logOutput.Flush();

            string logs = logOutput.ToString();
            Assert.Contains("fetched and parsed", logs);
            Assert.Contains("EventCount", logs);
        }

        [Fact]
        public async Task Job_OnSuccessfulFetch_LogsElapsedTime()
        {
            StringWriter logOutput = new();
            TrackingHttpHandler handler = new(SampleEventsJson);
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();
            logOutput.Flush();

            string logs = logOutput.ToString();
            Assert.Contains("ElapsedMs", logs);
        }

        [Fact]
        public async Task Job_OnFailedFetch_LogsErrorAtErrorLevel()
        {
            StringWriter logOutput = new();
            FailingHttpHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();
            logOutput.Flush();

            string logs = logOutput.ToString();
            Assert.Contains("Ingestion failed", logs);
        }

        [Fact]
        public async Task Job_OnFailedFetch_LogsIterationFailedError()
        {
            StringWriter logOutput = new();
            FailingHttpHandler handler = new();
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();
            logOutput.Flush();

            string logs = logOutput.ToString();
            Assert.Contains("ScrapedDuck ingestion job iteration failed", logs);
        }

        [Fact]
        public async Task Job_LogsUseStructuredJsonFormat()
        {
            StringWriter logOutput = new();
            TrackingHttpHandler handler = new(SampleEventsJson);
            using CancellationTokenSource cts = new();
            IHost host = BuildHostWithLogging(handler, logOutput, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob job = host.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = job.StartAsync(cts.Token);

            await WaitForFetch(handler, expectedCount: 1);
            cts.Cancel();
            logOutput.Flush();

            string logs = logOutput.ToString();
            // Verify structured JSON format (compact JSON uses @t for timestamp)
            Assert.Contains("\"@t\"", logs);
            Assert.Contains("\"@m\"", logs);
        }

        [Fact]
        public async Task Job_SuccessAndFailure_ProduceDifferentLogLevels()
        {
            // First: verify failure produces Error-level log
            StringWriter failLogOutput = new();
            FailingHttpHandler failHandler = new();
            using CancellationTokenSource failCts = new();
            IHost failHost = BuildHostWithLogging(failHandler, failLogOutput, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob failJob = failHost.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = failJob.StartAsync(failCts.Token);

            await WaitForFetch(failHandler, expectedCount: 1);
            failCts.Cancel();
            failLogOutput.Flush();

            string failLogs = failLogOutput.ToString();
            Assert.Contains("\"@l\":\"Error\"", failLogs);

            // Second: verify success produces Information-level log (no @l means Information in compact JSON)
            StringWriter successLogOutput = new();
            TrackingHttpHandler successHandler = new(SampleEventsJson);
            using CancellationTokenSource successCts = new();
            IHost successHost = BuildHostWithLogging(successHandler, successLogOutput, scheduleIntervalMinutes: 60);

            ScrapedDuckIngestionJob successJob = successHost.Services.GetRequiredService<ScrapedDuckIngestionJob>();
            _ = successJob.StartAsync(successCts.Token);

            await WaitForFetch(successHandler, expectedCount: 1);
            successCts.Cancel();
            successLogOutput.Flush();

            string successLogs = successLogOutput.ToString();
            Assert.Contains("fetched and parsed", successLogs);
            Assert.DoesNotContain("\"@l\":\"Error\"", successLogs);
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

        private static async Task WaitForFetch(TrackingHttpHandler handler, int expectedCount, int timeoutMs = 5000)
        {
            int elapsed = 0;
            while (handler.RequestCount < expectedCount && elapsed < timeoutMs)
            {
                await Task.Delay(50);
                elapsed += 50;
            }
            // Allow time for the full pipeline (parsing, logging, status update) to complete
            await Task.Delay(200);
        }

        private static async Task WaitForFetch(FailingHttpHandler handler, int expectedCount, int timeoutMs = 5000)
        {
            int elapsed = 0;
            while (handler.RequestCount < expectedCount && elapsed < timeoutMs)
            {
                await Task.Delay(50);
                elapsed += 50;
            }
            await Task.Delay(200);
        }

        private sealed class TrackingHttpHandler(string responseBody) : HttpMessageHandler
        {
            private volatile int _requestCount;
            public int RequestCount => _requestCount;

            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            {
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

        private sealed class FailingHttpHandler : HttpMessageHandler
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
    }
}
