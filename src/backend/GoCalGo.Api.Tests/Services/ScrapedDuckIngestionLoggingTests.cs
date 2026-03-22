using System.Net;
using GoCalGo.Api.Configuration;
using GoCalGo.Api.Data;
using GoCalGo.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Serilog;
using Serilog.Formatting.Compact;
using GoCalGo.Api.Tests.Configuration;

namespace GoCalGo.Api.Tests.Services
{
    public class ScrapedDuckIngestionLoggingTests
    {
        private static readonly string SampleEventsJson = """
            [
                {"eventID":"evt-1","name":"Community Day","eventType":"community-day","heading":"March CD","image":"img.png","link":"http://example.com","start":"2026-03-15 11:00","end":"2026-03-15 17:00","extraData":{}},
                {"eventID":"evt-2","name":"Spotlight Hour","eventType":"pokemon-spotlight-hour","heading":"Spotlight","image":"img2.png","link":"http://example.com","start":"2026-03-17 18:00","end":"2026-03-17 19:00","extraData":{}},
                {"eventID":"evt-3","name":"Raid Hour","eventType":"raid-hour","heading":"Raids","image":"img3.png","link":"http://example.com","start":"2026-03-18 18:00","end":"2026-03-18 19:00","extraData":{}}
            ]
            """;

        private static (ScrapedDuckIngestionService Service, StringWriter LogOutput, IngestionStatusTracker Tracker) CreateService(HttpMessageHandler handler)
        {
            StringWriter output = new();
            RenderedCompactJsonFormatter formatter = new();
            Serilog.Core.Logger serilogLogger = new LoggerConfiguration()
                .MinimumLevel.Debug()
                .WriteTo.Sink(new TextWriterSink(formatter, output))
                .CreateLogger();

            ILoggerFactory loggerFactory = new LoggerFactory().AddSerilog(serilogLogger);
            ILogger<ScrapedDuckClient> clientLogger = loggerFactory.CreateLogger<ScrapedDuckClient>();
            ILogger<ScrapedDuckIngestionService> serviceLogger = loggerFactory.CreateLogger<ScrapedDuckIngestionService>();

            HttpClient httpClient = new(handler) { BaseAddress = new Uri("https://test.example.com") };
            IOptions<ScrapedDuckSettings> settings = Options.Create(new ScrapedDuckSettings
            {
                BaseUrl = "https://test.example.com",
                CacheExpirationMinutes = 5
            });

            IngestionStatusTracker tracker = new();
            IScrapedDuckClient client = new ScrapedDuckClient(httpClient, settings, clientLogger);

            DbContextOptions<GoCalGoDbContext> dbOptions = new DbContextOptionsBuilder<GoCalGoDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            GoCalGoDbContext db = new(dbOptions);
            ICacheService cache = new NullCacheService();

            return (new ScrapedDuckIngestionService(client, db, cache, tracker, serviceLogger), output, tracker);
        }

        [Fact]
        public async Task FetchEvents_LogsEventCount()
        {
            FakeHttpHandler handler = new(SampleEventsJson);
            (ScrapedDuckIngestionService service, StringWriter logOutput, _) = CreateService(handler);

            await service.FetchEventsAsync();
            logOutput.Flush();

            string logs = logOutput.ToString();
            Assert.Contains("EventCount", logs);
            Assert.Contains("3", logs);
        }

        [Fact]
        public async Task FetchEvents_LogsElapsedTiming()
        {
            FakeHttpHandler handler = new(SampleEventsJson);
            (ScrapedDuckIngestionService service, StringWriter logOutput, _) = CreateService(handler);

            await service.FetchEventsAsync();
            logOutput.Flush();

            string logs = logOutput.ToString();
            Assert.Contains("ElapsedMs", logs);
        }

        [Fact]
        public async Task FetchEvents_LogsStartAndCompletionMessages()
        {
            FakeHttpHandler handler = new(SampleEventsJson);
            (ScrapedDuckIngestionService service, StringWriter logOutput, _) = CreateService(handler);

            await service.FetchEventsAsync();
            logOutput.Flush();

            string logs = logOutput.ToString();
            Assert.Contains("ScrapedDuck client: fetching events from", logs);
            Assert.Contains("fetched and parsed", logs);
        }

        [Fact]
        public async Task FetchEvents_ReturnsCorrectEventCount()
        {
            FakeHttpHandler handler = new(SampleEventsJson);
            (ScrapedDuckIngestionService service, _, _) = CreateService(handler);

            IReadOnlyList<ParsedEvent> events = await service.FetchEventsAsync();

            Assert.Equal(3, events.Count);
        }

        [Fact]
        public async Task FetchEvents_UsesStructuredProperties()
        {
            FakeHttpHandler handler = new(SampleEventsJson);
            (ScrapedDuckIngestionService service, StringWriter logOutput, _) = CreateService(handler);

            await service.FetchEventsAsync();
            logOutput.Flush();

            string logs = logOutput.ToString();
            Assert.Contains("\"EventCount\"", logs);
            Assert.Contains("\"ElapsedMs\"", logs);
            Assert.Contains("\"Url\"", logs);
        }

        [Fact]
        public async Task FetchEvents_OnSuccess_UpdatesStatusTracker()
        {
            FakeHttpHandler handler = new(SampleEventsJson);
            (ScrapedDuckIngestionService service, _, IngestionStatusTracker tracker) = CreateService(handler);

            await service.FetchEventsAsync();

            Assert.True(tracker.LastFetchSuccess);
            Assert.Equal(3, tracker.LastFetchEventCount);
            Assert.NotNull(tracker.LastFetchTime);
        }

        [Fact]
        public async Task FetchEvents_OnFailure_LogsError()
        {
            FailingHttpHandler handler = new();
            (ScrapedDuckIngestionService service, StringWriter logOutput, _) = CreateService(handler);

            await Assert.ThrowsAsync<ScrapedDuckClientException>(() => service.FetchEventsAsync());
            logOutput.Flush();

            string logs = logOutput.ToString();
            Assert.Contains("Ingestion failed", logs);
        }

        [Fact]
        public async Task FetchEvents_OnFailure_UpdatesStatusTracker()
        {
            FailingHttpHandler handler = new();
            (ScrapedDuckIngestionService service, _, IngestionStatusTracker tracker) = CreateService(handler);

            await Assert.ThrowsAsync<ScrapedDuckClientException>(() => service.FetchEventsAsync());

            Assert.False(tracker.LastFetchSuccess);
            Assert.NotNull(tracker.LastFetchTime);
        }

        private sealed class FakeHttpHandler(string responseBody) : HttpMessageHandler
        {
            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            {
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(responseBody, System.Text.Encoding.UTF8, "application/json")
                });
            }
        }

        private sealed class FailingHttpHandler : HttpMessageHandler
        {
            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            {
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent("Server Error")
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
