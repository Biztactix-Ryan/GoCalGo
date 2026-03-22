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
using Microsoft.Extensions.Logging.Abstractions;

namespace GoCalGo.Api.Tests.Api
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-36:
    /// "Redis outage: API falls back to PostgreSQL queries with no user-visible error"
    ///
    /// When Redis is completely unavailable, all API endpoints must:
    /// 1. Return HTTP 200 (no user-visible error)
    /// 2. Serve correct data from PostgreSQL
    /// 3. Report cacheHit = false
    /// </summary>
    public class RedisOutageGracefulDegradationTests
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
                        Text = "3× Catch XP",
                        Category = ModelBuffCategory.Multiplier,
                        Multiplier = 3.0,
                        Resource = "XP",
                    },
                ],
            };
        }

        /// <summary>
        /// Factory simulating a complete Redis outage: all cache operations throw.
        /// Uses ResilientCacheService wrapping a FailingCacheService to match production DI.
        /// </summary>
        private sealed class RedisOutageFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "RedisOutageTest_" + Guid.NewGuid();

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");
                builder.ConfigureServices(services =>
                {
                    ReplaceDbWithInMemory(services, _dbName);

                    ICacheService resilient = new ResilientCacheService(
                        new FailingCacheService(),
                        NullLogger<ResilientCacheService>.Instance);
                    ReplaceCacheWith(services, resilient);

                    services.RemoveAll<IHostedService>();
                });
            }
        }

        [Fact]
        public async Task GetEvents_WhenRedisDown_ReturnsOk_WithDbData()
        {
            using RedisOutageFactory factory = new();

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
            Assert.False(eventsResponse.CacheHit, "Should indicate cache miss when Redis is down");
            Assert.Equal(2, eventsResponse.Events.Count);
        }

        [Fact]
        public async Task GetActiveEvents_WhenRedisDown_ReturnsOk_WithActiveDbEvents()
        {
            using RedisOutageFactory factory = new();

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(CreateTestEvent("evt-active", "Active Event",
                    DateTime.UtcNow.AddHours(-1), DateTime.UtcNow.AddHours(5)));
                db.Events.Add(CreateTestEvent("evt-future", "Future Event",
                    DateTime.UtcNow.AddDays(1), DateTime.UtcNow.AddDays(1).AddHours(3)));
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/active");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            ActiveEventsResponse? activeResponse = JsonSerializer.Deserialize<ActiveEventsResponse>(json, JsonOptions);

            Assert.NotNull(activeResponse);
            Assert.False(activeResponse.CacheHit, "Should indicate cache miss when Redis is down");
            Assert.Single(activeResponse.Events);
            Assert.Equal("Active Event", activeResponse.Events[0].Name);
        }

        [Fact]
        public async Task GetUpcomingEvents_WhenRedisDown_ReturnsOk_WithUpcomingDbEvents()
        {
            using RedisOutageFactory factory = new();

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(CreateTestEvent("evt-active", "Active Event",
                    DateTime.UtcNow.AddHours(-1), DateTime.UtcNow.AddHours(5)));
                db.Events.Add(CreateTestEvent("evt-upcoming", "Upcoming Event",
                    DateTime.UtcNow.AddDays(2), DateTime.UtcNow.AddDays(2).AddHours(3)));
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/upcoming?days=7");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.False(eventsResponse.CacheHit, "Should indicate cache miss when Redis is down");
            Assert.Single(eventsResponse.Events);
            Assert.Equal("Upcoming Event", eventsResponse.Events[0].Name);
        }

        [Fact]
        public async Task GetEvents_WhenRedisDown_ResponseIncludesBuffData()
        {
            using RedisOutageFactory factory = new();

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(CreateTestEvent("evt-buffs", "Buff Event"));
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            EventDto evt = Assert.Single(eventsResponse.Events);
            Assert.NotEmpty(evt.Buffs);
            Assert.Equal("3× Catch XP", evt.Buffs[0].Text);
        }

        [Fact]
        public async Task GetEvents_WhenRedisDown_MultipleRequests_AllSucceed()
        {
            using RedisOutageFactory factory = new();

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(CreateTestEvent("evt-1", "Event One"));
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();

            // Multiple sequential requests should all succeed — no cascading failures
            for (int i = 0; i < 3; i++)
            {
                HttpResponseMessage response = await client.GetAsync("/api/v1/events");
                Assert.Equal(HttpStatusCode.OK, response.StatusCode);

                string json = await response.Content.ReadAsStringAsync();
                EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

                Assert.NotNull(eventsResponse);
                Assert.NotEmpty(eventsResponse.Events);
            }
        }

        [Fact]
        public async Task AllEndpoints_WhenRedisDown_NoneReturnServerError()
        {
            using RedisOutageFactory factory = new();

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(CreateTestEvent("evt-1", "Test Event",
                    DateTime.UtcNow.AddHours(-1), DateTime.UtcNow.AddHours(5)));
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();

            string[] endpoints = ["/api/v1/events", "/api/v1/events/active", "/api/v1/events/upcoming"];

            foreach (string endpoint in endpoints)
            {
                HttpResponseMessage response = await client.GetAsync(endpoint);
                Assert.True(
                    response.StatusCode == HttpStatusCode.OK,
                    $"{endpoint} returned {response.StatusCode} — expected OK (no user-visible error)");
            }
        }

        #region Test Doubles

        private sealed class FailingCacheService : ICacheService
        {
            public Task<string?> GetAsync(string key)
            {
                throw new InvalidOperationException("Redis connection refused");
            }

            public Task SetAsync(string key, string value, TimeSpan? ttl = null)
            {
                throw new InvalidOperationException("Redis connection refused");
            }

            public Task InvalidateAsync(string key)
            {
                throw new InvalidOperationException("Redis connection refused");
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
