using System.Net;
using System.Text.Json;
using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using GoCalGo.Contracts.Events;
using ModelBuffCategory = GoCalGo.Api.Models.BuffCategory;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;

namespace GoCalGo.Api.Tests.Api
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-36:
    /// "ScrapedDuck outage: backend serves cached data from PostgreSQL with degraded status"
    ///
    /// End-to-end integration tests proving that when ScrapedDuck is unavailable:
    /// 1. API endpoints still serve previously ingested event data from PostgreSQL
    /// 2. Health endpoint reports overall "degraded" status
    /// 3. ScrapedDuck subsystem reports "unhealthy"
    /// </summary>
    public class ScrapedDuckOutageGracefulDegradationTests
    {
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
        };

        private static Event CreateTestEvent(string id, string name, DateTime? start = null, DateTime? end = null)
        {
            return new()
            {
                Id = id,
                Name = name,
                EventType = EventType.CommunityDay,
                Heading = $"{name} heading",
                ImageUrl = "https://example.com/img.png",
                LinkUrl = "https://example.com/event",
                Start = start ?? DateTime.UtcNow.AddHours(-1),
                End = end ?? DateTime.UtcNow.AddHours(5),
                IsUtcTime = true,
                HasSpawns = true,
                HasResearchTasks = false,
                Buffs =
                [
                    new EventBuff
                    {
                        Text = "2× Catch XP",
                        Category = ModelBuffCategory.Multiplier,
                        Multiplier = 2.0,
                        Resource = "XP",
                    },
                ],
            };
        }

        /// <summary>
        /// Factory simulating ScrapedDuck outage: cache is empty (no recent refresh),
        /// IngestionStatusTracker reports failure, DB has previously ingested data.
        /// </summary>
        private sealed class ScrapedDuckOutageFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "ScrapedDuckOutageTest_" + Guid.NewGuid();
            public IngestionStatusTracker StatusTracker { get; } = new()
            {
                LastFetchTime = DateTime.UtcNow.AddMinutes(-30),
                LastFetchSuccess = false,
                LastFetchEventCount = 0,
            };

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");
                builder.ConfigureServices(services =>
                {
                    ReplaceDbWithInMemory(services, _dbName);
                    ReplaceCacheWith(services, new EmptyCacheService());
                    services.RemoveAll<IHostedService>();
                    services.RemoveAll<IngestionStatusTracker>();
                    services.AddSingleton(StatusTracker);
                });
            }
        }

        [Fact]
        public async Task GetEvents_WhenScrapedDuckDown_ServesDataFromPostgreSQL()
        {
            using ScrapedDuckOutageFactory factory = new();

            // Seed PostgreSQL with previously ingested events
            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(CreateTestEvent("evt-1", "Community Day: Charmander"));
                db.Events.Add(CreateTestEvent("evt-2", "Spotlight Hour: Pikachu"));
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.False(eventsResponse.CacheHit, "Should fall back to DB when cache is empty during outage");
            Assert.Equal(2, eventsResponse.Events.Count);
        }

        [Fact]
        public async Task GetActiveEvents_WhenScrapedDuckDown_ServesActiveEventsFromPostgreSQL()
        {
            using ScrapedDuckOutageFactory factory = new();

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                // Active event: started 1 hour ago, ends in 5 hours
                db.Events.Add(CreateTestEvent("evt-active", "Active Event",
                    DateTime.UtcNow.AddHours(-1), DateTime.UtcNow.AddHours(5)));
                // Future event: starts tomorrow
                db.Events.Add(CreateTestEvent("evt-future", "Future Event",
                    DateTime.UtcNow.AddDays(1), DateTime.UtcNow.AddDays(1).AddHours(3)));
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/active");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(json);
            JsonElement events = doc.RootElement.GetProperty("events");

            Assert.Equal(1, events.GetArrayLength());
            Assert.Equal("Active Event", events[0].GetProperty("name").GetString());
        }

        [Fact]
        public async Task HealthEndpoint_WhenScrapedDuckDown_ReportsDegradedStatus()
        {
            using ScrapedDuckOutageFactory factory = new();

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/health");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(json);

            string? overallStatus = doc.RootElement.GetProperty("status").GetString();
            Assert.Equal("degraded", overallStatus);
        }

        [Fact]
        public async Task HealthEndpoint_WhenScrapedDuckDown_SubsystemReportsUnhealthy()
        {
            using ScrapedDuckOutageFactory factory = new();

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/health");

            string json = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(json);

            JsonElement scrapedDuck = doc.RootElement
                .GetProperty("subsystems")
                .GetProperty("scrapedDuck");

            Assert.Equal("unhealthy", scrapedDuck.GetProperty("status").GetString());
        }

        [Fact]
        public async Task HealthEndpoint_WhenScrapedDuckDown_DatabaseStillHealthy()
        {
            using ScrapedDuckOutageFactory factory = new();

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/health");

            string json = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(json);

            JsonElement database = doc.RootElement
                .GetProperty("subsystems")
                .GetProperty("database");

            Assert.Equal("healthy", database.GetProperty("status").GetString());
        }

        [Fact]
        public async Task GetEvents_WhenScrapedDuckDown_ResponseIncludesBuffData()
        {
            using ScrapedDuckOutageFactory factory = new();

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(CreateTestEvent("evt-with-buffs", "Buff Event"));
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            EventDto evt = Assert.Single(eventsResponse.Events);
            Assert.NotEmpty(evt.Buffs);
            Assert.Equal("2× Catch XP", evt.Buffs[0].Text);
        }

        #region Test Doubles

        private sealed class EmptyCacheService : ICacheService
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

        #region Shared DI Helpers

        private static void ReplaceDbWithInMemory(IServiceCollection services, string dbName)
        {
            List<ServiceDescriptor> dbDescriptors = [.. services
                .Where(d => d.ServiceType.FullName?.Contains("EntityFrameworkCore") == true
                         || d.ServiceType.FullName?.Contains("Npgsql") == true
                         || d.ServiceType == typeof(DbContextOptions<GoCalGoDbContext>)
                         || d.ImplementationType?.FullName?.Contains("Npgsql") == true
                         || d.ImplementationType?.FullName?.Contains("EntityFrameworkCore") == true)];
            foreach (ServiceDescriptor descriptor in dbDescriptors)
            {
                services.Remove(descriptor);
            }

            services.AddDbContext<GoCalGoDbContext>(options =>
                options.UseInMemoryDatabase(dbName));
        }

        private static void ReplaceCacheWith(IServiceCollection services, ICacheService replacement)
        {
            services.RemoveAll<StackExchange.Redis.IConnectionMultiplexer>();
            services.RemoveAll<RedisCacheService>();
            services.RemoveAll<ICacheService>();
            services.AddSingleton<ICacheService>(replacement);
        }

        #endregion
    }
}
