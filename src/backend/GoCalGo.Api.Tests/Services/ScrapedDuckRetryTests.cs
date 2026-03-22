using System.Net;
using System.Text;
using GoCalGo.Api.Configuration;
using GoCalGo.Api.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Polly;
using Polly.Extensions.Http;

namespace GoCalGo.Api.Tests.Services
{
    public class ScrapedDuckRetryTests
    {
        private static readonly string SampleEventsJson = """
            [
                {"eventID":"evt-1","name":"Community Day","eventType":"community-day","heading":"March CD","image":"img.png","link":"http://example.com","start":"2026-03-15 11:00","end":"2026-03-15 17:00","extraData":{}}
            ]
            """;

        [Fact]
        public async Task Client_RetriesOnTransientFailure_AndEventuallySucceeds()
        {
            // Arrange: fail twice with 503, then succeed
            FailThenSucceedHandler handler = new(SampleEventsJson, failCount: 2);
            ScrapedDuckClient client = BuildClient(handler);

            // Act
            IReadOnlyList<ParsedEvent> events = await client.FetchEventsAsync();

            // Assert: 2 failures + 1 success = 3 total requests
            Assert.Equal(3, handler.RequestCount);
            Assert.Single(events);
        }

        [Fact]
        public async Task Client_RetriesOnHttpRequestException_AndEventuallySucceeds()
        {
            // Arrange: throw HttpRequestException once, then succeed
            ExceptionThenSucceedHandler handler = new(SampleEventsJson, failCount: 1);
            ScrapedDuckClient client = BuildClient(handler);

            // Act
            IReadOnlyList<ParsedEvent> events = await client.FetchEventsAsync();

            // Assert: 1 failure + 1 success = 2 total requests
            Assert.Equal(2, handler.RequestCount);
            Assert.Single(events);
        }

        [Fact]
        public async Task Client_ThrowsAfterAllRetriesExhausted()
        {
            // Arrange: fail more times than max retries (3 retries = 4 total attempts)
            FailThenSucceedHandler handler = new(SampleEventsJson, failCount: 10);
            ScrapedDuckClient client = BuildClient(handler);

            // Act & Assert: should throw after exhausting retries
            await Assert.ThrowsAsync<ScrapedDuckClientException>(
                () => client.FetchEventsAsync());

            // 1 initial + 3 retries = 4 total attempts
            Assert.Equal(4, handler.RequestCount);
        }

        [Fact]
        public async Task Client_UsesExponentialBackoff()
        {
            // Arrange: fail 2 times then succeed = exactly 2 retries to observe timing
            TimingHandler handler = new(SampleEventsJson, failCount: 2);
            ScrapedDuckClient client = BuildClient(handler);

            await client.FetchEventsAsync();

            // Assert: verify delays increase exponentially (2s, 4s pattern)
            Assert.Equal(3, handler.RequestCount);
            Assert.Equal(3, handler.RequestTimestamps.Count);

            TimeSpan firstRetryDelay = handler.RequestTimestamps[1] - handler.RequestTimestamps[0];
            TimeSpan secondRetryDelay = handler.RequestTimestamps[2] - handler.RequestTimestamps[1];

            // Exponential backoff: 2^1=2s, 2^2=4s (with tolerance)
            Assert.True(firstRetryDelay >= TimeSpan.FromSeconds(1.5),
                $"First retry delay {firstRetryDelay.TotalSeconds:F1}s should be ~2s");
            Assert.True(firstRetryDelay <= TimeSpan.FromSeconds(3.0),
                $"First retry delay {firstRetryDelay.TotalSeconds:F1}s should be ~2s");

            Assert.True(secondRetryDelay >= TimeSpan.FromSeconds(3.0),
                $"Second retry delay {secondRetryDelay.TotalSeconds:F1}s should be ~4s");
            Assert.True(secondRetryDelay <= TimeSpan.FromSeconds(6.0),
                $"Second retry delay {secondRetryDelay.TotalSeconds:F1}s should be ~4s");

            // Second delay should be roughly double the first
            Assert.True(secondRetryDelay > firstRetryDelay,
                "Backoff should be exponential: second delay must be larger than first");
        }

        [Fact]
        public async Task Client_DoesNotRetryOnNonTransientErrors()
        {
            // Arrange: return 400 Bad Request (not transient, should not retry)
            FixedStatusHandler handler = new(HttpStatusCode.BadRequest);
            ScrapedDuckClient client = BuildClient(handler);

            // Act & Assert
            await Assert.ThrowsAsync<ScrapedDuckClientException>(
                () => client.FetchEventsAsync());

            // Should not retry on 400
            Assert.Equal(1, handler.RequestCount);
        }

        private static ScrapedDuckClient BuildClient(HttpMessageHandler handler)
        {
            ServiceCollection services = new();
            services.Configure<ScrapedDuckSettings>(opts =>
            {
                opts.BaseUrl = "https://test.example.com";
            });
            services.AddLogging(b => b.AddDebug());
            services.AddHttpClient<ScrapedDuckClient>()
                .ConfigurePrimaryHttpMessageHandler(() => handler)
                .AddPolicyHandler(HttpPolicyExtensions
                    .HandleTransientHttpError()
                    .WaitAndRetryAsync(3, retryAttempt =>
                        TimeSpan.FromSeconds(Math.Pow(2, retryAttempt))));

            ServiceProvider sp = services.BuildServiceProvider();
            return sp.GetRequiredService<ScrapedDuckClient>();
        }

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
                        Content = new StringContent(responseBody, Encoding.UTF8, "application/json")
                    });
            }
        }

        private sealed class ExceptionThenSucceedHandler(string responseBody, int failCount) : HttpMessageHandler
        {
            private volatile int _requestCount;
            public int RequestCount => _requestCount;

            protected override Task<HttpResponseMessage> SendAsync(
                HttpRequestMessage request, CancellationToken cancellationToken)
            {
                int current = Interlocked.Increment(ref _requestCount);

                return current <= failCount
                    ? throw new HttpRequestException("Connection refused")
                    : Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                    {
                        Content = new StringContent(responseBody, Encoding.UTF8, "application/json")
                    });
            }
        }

        private sealed class TimingHandler(string responseBody, int failCount) : HttpMessageHandler
        {
            private volatile int _requestCount;
            public int RequestCount => _requestCount;
            public List<DateTimeOffset> RequestTimestamps { get; } = [];

            protected override Task<HttpResponseMessage> SendAsync(
                HttpRequestMessage request, CancellationToken cancellationToken)
            {
                int current = Interlocked.Increment(ref _requestCount);
                lock (RequestTimestamps)
                {
                    RequestTimestamps.Add(DateTimeOffset.UtcNow);
                }

                return current <= failCount
                    ? Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
                    {
                        Content = new StringContent("Service Unavailable")
                    })
                    : Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                    {
                        Content = new StringContent(responseBody, Encoding.UTF8, "application/json")
                    });
            }
        }

        private sealed class FixedStatusHandler(HttpStatusCode statusCode) : HttpMessageHandler
        {
            private volatile int _requestCount;
            public int RequestCount => _requestCount;

            protected override Task<HttpResponseMessage> SendAsync(
                HttpRequestMessage request, CancellationToken cancellationToken)
            {
                Interlocked.Increment(ref _requestCount);
                return Task.FromResult(new HttpResponseMessage(statusCode)
                {
                    Content = new StringContent("Error")
                });
            }
        }
    }
}
