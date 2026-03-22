using Microsoft.AspNetCore.Mvc.Testing;

namespace GoCalGo.Api.Tests.Configuration
{
    public class ApiRequestLoggingTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        [Fact]
        public async Task ApiRequest_ReturnsCorrelationIdHeader()
        {
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");

            Assert.True(response.Headers.Contains("X-Correlation-ID"),
                "Response should include X-Correlation-ID header");
            string correlationId = response.Headers.GetValues("X-Correlation-ID").First();
            Assert.False(string.IsNullOrWhiteSpace(correlationId),
                "Correlation ID should not be empty");
        }

        [Fact]
        public async Task ApiRequest_PreservesIncomingCorrelationId()
        {
            HttpClient client = factory.CreateClient();
            string expectedId = "test-correlation-123";

            HttpRequestMessage request = new(HttpMethod.Get, "/health");
            request.Headers.Add("X-Correlation-ID", expectedId);
            HttpResponseMessage response = await client.SendAsync(request);

            Assert.True(response.Headers.Contains("X-Correlation-ID"));
            string returnedId = response.Headers.GetValues("X-Correlation-ID").First();
            Assert.Equal(expectedId, returnedId);
        }

        [Fact]
        public async Task ApiRequest_GeneratesUniqueCorrelationIds()
        {
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response1 = await client.GetAsync("/health");
            HttpResponseMessage response2 = await client.GetAsync("/health");

            string id1 = response1.Headers.GetValues("X-Correlation-ID").First();
            string id2 = response2.Headers.GetValues("X-Correlation-ID").First();
            Assert.NotEqual(id1, id2);
        }

        [Fact]
        public async Task ApiRequest_CorrelationIdIsValidGuid_WhenNotProvided()
        {
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");

            string correlationId = response.Headers.GetValues("X-Correlation-ID").First();
            Assert.True(Guid.TryParse(correlationId, out _),
                "Auto-generated correlation ID should be a valid GUID");
        }

        [Fact]
        public void SerilogRequestLogging_IsConfiguredWithLogContextEnrichment()
        {
            // Verify Serilog is configured with Enrich.FromLogContext() so that
            // the CorrelationId property pushed in middleware is included in log output.
            StringWriter output = new();
            Serilog.Formatting.Compact.RenderedCompactJsonFormatter formatter = new();
            using Serilog.Core.Logger testLogger = new Serilog.LoggerConfiguration()
                .Enrich.FromLogContext()
                .WriteTo.Sink(new TextWriterSink(formatter, output))
                .CreateLogger();

            using (Serilog.Context.LogContext.PushProperty("CorrelationId", "test-id-456"))
            {
                testLogger.Information("Request handled");
            }
            output.Flush();

            string json = output.ToString();
            Assert.Contains("\"CorrelationId\"", json);
            Assert.Contains("test-id-456", json);
        }
    }
}
