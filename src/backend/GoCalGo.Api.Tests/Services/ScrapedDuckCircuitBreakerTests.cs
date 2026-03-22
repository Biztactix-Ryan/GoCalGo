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
    public class ScrapedDuckCircuitBreakerTests
    {
        private static readonly string SampleEventsJson = """
            [
                {"eventID":"evt-1","name":"Community Day","eventType":"community-day","heading":"March CD","image":"img.png","link":"http://example.com","start":"2026-03-15 11:00","end":"2026-03-15 17:00","extraData":{}}
            ]
            """;

        [Fact]
        public async Task CircuitBreaker_OpensAfterConsecutiveFailures()
        {
            // Arrange: always fail — circuit should open after threshold
            AlwaysFailHandler handler = new();
            ScrapedDuckClient client = BuildClient(handler, handledEventsBeforeBreaking: 3, breakDuration: TimeSpan.FromSeconds(30));

            // Act: exhaust retries to trigger circuit breaker
            // Each call goes through retry (1 initial + 3 retries = 4 attempts per call)
            // With handledEventsBeforeBreaking=3, the circuit opens after 3 handled failures
            // at the circuit breaker level (each failed retry attempt counts)
            try { await client.FetchEventsAsync(); } catch { }

            int requestsBeforeBreak = handler.RequestCount;

            // Act: next call should be rejected immediately by the open circuit
            try { await client.FetchEventsAsync(); } catch { }

            // Assert: no additional HTTP requests were made (circuit is open)
            int requestsAfterBreak = handler.RequestCount;
            Assert.True(requestsAfterBreak <= requestsBeforeBreak + 1,
                $"Circuit should block most requests once open. Before: {requestsBeforeBreak}, After: {requestsAfterBreak}");
        }

        [Fact]
        public async Task CircuitBreaker_PreventsRequestsDuringOpenState()
        {
            // Arrange: always fail to open the circuit
            CountingHandler handler = new();
            ScrapedDuckClient client = BuildClient(handler, handledEventsBeforeBreaking: 2, breakDuration: TimeSpan.FromSeconds(60));

            // Trigger enough failures to open the circuit
            for (int i = 0; i < 3; i++)
            {
                try { await client.FetchEventsAsync(); } catch { }
            }

            int requestCountAfterOpening = handler.RequestCount;

            // Act: make several more calls while circuit is open
            for (int i = 0; i < 5; i++)
            {
                try { await client.FetchEventsAsync(); } catch { }
            }

            // Assert: circuit should have blocked most/all subsequent requests
            int additionalRequests = handler.RequestCount - requestCountAfterOpening;
            Assert.True(additionalRequests <= 1,
                $"Open circuit should prevent cascading calls. Got {additionalRequests} additional requests.");
        }

        [Fact]
        public async Task CircuitBreaker_AllowsRequestsAfterBreakDuration()
        {
            // Arrange: fail initially, then succeed (simulating recovery)
            RecoverableHandler handler = new(SampleEventsJson, failUntilRequest: 10);
            ScrapedDuckClient client = BuildClient(handler, handledEventsBeforeBreaking: 2, breakDuration: TimeSpan.FromSeconds(1));

            // Trigger failures to open the circuit
            for (int i = 0; i < 3; i++)
            {
                try { await client.FetchEventsAsync(); } catch { }
            }

            // Wait for the break duration to elapse (circuit moves to half-open)
            await Task.Delay(TimeSpan.FromSeconds(1.5));

            // Switch handler to succeed mode
            handler.StartSucceeding();

            // Act: attempt a call — circuit should be half-open and allow a probe request
            IReadOnlyList<ParsedEvent> events = await client.FetchEventsAsync();

            // Assert: request succeeded, circuit is closed again
            Assert.Single(events);
        }

        [Fact]
        public async Task CircuitBreaker_DoesNotOpenOnSuccessfulRequests()
        {
            // Arrange: always succeed
            AlwaysSucceedHandler handler = new(SampleEventsJson);
            ScrapedDuckClient client = BuildClient(handler, handledEventsBeforeBreaking: 3, breakDuration: TimeSpan.FromSeconds(30));

            // Act: make many successful requests
            for (int i = 0; i < 10; i++)
            {
                IReadOnlyList<ParsedEvent> events = await client.FetchEventsAsync();
                Assert.Single(events);
            }

            // Assert: all requests went through (circuit never opened)
            Assert.Equal(10, handler.RequestCount);
        }

        private static ScrapedDuckClient BuildClient(HttpMessageHandler handler, int handledEventsBeforeBreaking, TimeSpan breakDuration)
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
                        TimeSpan.FromSeconds(Math.Pow(2, retryAttempt))))
                .AddPolicyHandler(HttpPolicyExtensions
                    .HandleTransientHttpError()
                    .CircuitBreakerAsync(
                        handledEventsAllowedBeforeBreaking: handledEventsBeforeBreaking,
                        durationOfBreak: breakDuration));

            ServiceProvider sp = services.BuildServiceProvider();
            return sp.GetRequiredService<ScrapedDuckClient>();
        }

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

        private sealed class CountingHandler : HttpMessageHandler
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

        private sealed class RecoverableHandler(string responseBody, int failUntilRequest) : HttpMessageHandler
        {
            private volatile int _requestCount;
            private volatile bool _shouldSucceed;
            public int RequestCount => _requestCount;

            public void StartSucceeding()
            {
                _shouldSucceed = true;
            }

            protected override Task<HttpResponseMessage> SendAsync(
                HttpRequestMessage request, CancellationToken cancellationToken)
            {
                int current = Interlocked.Increment(ref _requestCount);

                return _shouldSucceed || current > failUntilRequest
                    ? Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                    {
                        Content = new StringContent(responseBody, Encoding.UTF8, "application/json")
                    })
                    : Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
                    {
                        Content = new StringContent("Service Unavailable")
                    });
            }
        }

        private sealed class AlwaysSucceedHandler(string responseBody) : HttpMessageHandler
        {
            private volatile int _requestCount;
            public int RequestCount => _requestCount;

            protected override Task<HttpResponseMessage> SendAsync(
                HttpRequestMessage request, CancellationToken cancellationToken)
            {
                Interlocked.Increment(ref _requestCount);
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(responseBody, Encoding.UTF8, "application/json")
                });
            }
        }
    }
}
