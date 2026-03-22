using System.Net;
using System.Text.Json;
using GoCalGo.Api.Services;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace GoCalGo.Api.Tests.Configuration
{
    public class HealthCheckSubsystemTests(WebApplicationFactory<Program> factory) : IClassFixture<WebApplicationFactory<Program>>
    {
        [Fact]
        public async Task HealthEndpoint_ReturnsOk()
        {
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        }

        [Fact]
        public async Task HealthEndpoint_ReportsOverallStatus()
        {
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            JsonDocument doc = await ParseResponseAsync(response);

            Assert.True(doc.RootElement.TryGetProperty("status", out JsonElement status),
                "Health response should include a 'status' field");
            Assert.False(string.IsNullOrEmpty(status.GetString()),
                "Overall status should not be empty");
        }

        [Fact]
        public async Task HealthEndpoint_ReportsDatabaseStatus()
        {
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            JsonDocument doc = await ParseResponseAsync(response);

            JsonElement subsystems = doc.RootElement.GetProperty("subsystems");
            Assert.True(subsystems.TryGetProperty("database", out JsonElement database),
                "Health response should include database subsystem");
            Assert.True(database.TryGetProperty("status", out JsonElement dbStatus),
                "Database subsystem should include a status field");
            Assert.False(string.IsNullOrEmpty(dbStatus.GetString()),
                "Database status should not be empty");
        }

        [Fact]
        public async Task HealthEndpoint_ReportsRedisStatus()
        {
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            JsonDocument doc = await ParseResponseAsync(response);

            JsonElement subsystems = doc.RootElement.GetProperty("subsystems");
            Assert.True(subsystems.TryGetProperty("redis", out JsonElement redis),
                "Health response should include redis subsystem");
            Assert.True(redis.TryGetProperty("status", out JsonElement redisStatus),
                "Redis subsystem should include a status field");
            Assert.True(redis.TryGetProperty("host", out _),
                "Redis subsystem should include host info");
            Assert.True(redis.TryGetProperty("port", out _),
                "Redis subsystem should include port info");
            Assert.False(string.IsNullOrEmpty(redisStatus.GetString()),
                "Redis status should not be empty");
        }

        [Fact]
        public async Task HealthEndpoint_ReportsScrapedDuckStatus()
        {
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            JsonDocument doc = await ParseResponseAsync(response);

            JsonElement subsystems = doc.RootElement.GetProperty("subsystems");
            Assert.True(subsystems.TryGetProperty("scrapedDuck", out JsonElement scrapedDuck),
                "Health response should include scrapedDuck subsystem");
            Assert.True(scrapedDuck.TryGetProperty("status", out _),
                "ScrapedDuck subsystem should include a status field");
            Assert.True(scrapedDuck.TryGetProperty("lastFetch", out _),
                "ScrapedDuck subsystem should include lastFetch field");
            Assert.True(scrapedDuck.TryGetProperty("lastFetchEventCount", out _),
                "ScrapedDuck subsystem should include lastFetchEventCount field");
        }

        [Fact]
        public async Task HealthEndpoint_ScrapedDuckShowsUnknown_WhenNoFetchHasOccurred()
        {
            HttpClient client = factory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            JsonDocument doc = await ParseResponseAsync(response);

            JsonElement scrapedDuck = doc.RootElement.GetProperty("subsystems").GetProperty("scrapedDuck");
            string? status = scrapedDuck.GetProperty("status").GetString();
            Assert.Equal("unknown", status);
            Assert.Equal(JsonValueKind.Null, scrapedDuck.GetProperty("lastFetch").ValueKind);
        }

        [Fact]
        public async Task HealthEndpoint_ScrapedDuckReportsLastFetch_WhenFetchHasOccurred()
        {
            DateTime fetchTime = new(2026, 3, 21, 10, 0, 0, DateTimeKind.Utc);
            WebApplicationFactory<Program> customFactory = factory.WithWebHostBuilder(builder =>
            {
                builder.ConfigureServices(services =>
                {
                    // Pre-populate the ingestion tracker with a successful fetch
                    ServiceDescriptor? existing = services.FirstOrDefault(d => d.ServiceType == typeof(IngestionStatusTracker));
                    if (existing != null)
                    {
                        services.Remove(existing);
                    }

                    IngestionStatusTracker tracker = new()
                    {
                        LastFetchTime = fetchTime,
                        LastFetchEventCount = 5,
                        LastFetchSuccess = true
                    };
                    services.AddSingleton(tracker);
                });
            });

            HttpClient client = customFactory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/health");
            JsonDocument doc = await ParseResponseAsync(response);

            JsonElement scrapedDuck = doc.RootElement.GetProperty("subsystems").GetProperty("scrapedDuck");
            Assert.Equal("healthy", scrapedDuck.GetProperty("status").GetString());
            Assert.NotEqual(JsonValueKind.Null, scrapedDuck.GetProperty("lastFetch").ValueKind);
            Assert.Equal(5, scrapedDuck.GetProperty("lastFetchEventCount").GetInt32());
        }

        private static async Task<JsonDocument> ParseResponseAsync(HttpResponseMessage response)
        {
            string content = await response.Content.ReadAsStringAsync();
            return JsonDocument.Parse(content);
        }
    }
}
