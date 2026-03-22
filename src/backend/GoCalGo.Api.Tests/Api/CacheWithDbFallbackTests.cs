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
    /// Verifies acceptance criterion for story US-GCG-5:
    /// "Responses are served from Redis cache with PostgreSQL fallback"
    ///
    /// Tests the /api/events endpoint to confirm:
    /// 1. When cache has data, response is served from cache (cacheHit = true)
    /// 2. When cache is empty, response falls back to PostgreSQL (cacheHit = false)
    /// 3. When cache is unavailable (Redis down), response still comes from PostgreSQL
    /// </summary>
    public class CacheWithDbFallbackTests
    {
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
        };

        private static Event CreateTestEvent(string id = "test-event-1")
        {
            return new()
            {
                Id = id,
                Name = "Community Day: Charmander",
                EventType = EventType.CommunityDay,
                Heading = "Catch Charmander!",
                ImageUrl = "https://example.com/charmander.png",
                LinkUrl = "https://example.com/community-day",
                Start = DateTime.UtcNow.AddHours(-1),
                End = DateTime.UtcNow.AddHours(5),
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
        /// Factory with a working in-memory cache, seeded with event data.
        /// Simulates a cache hit scenario.
        /// </summary>
        private sealed class CacheHitFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "CacheHitTest_" + Guid.NewGuid();

            public InMemoryCacheService Cache { get; } = new();

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");
                builder.ConfigureServices(services =>
                {
                    ReplaceDbWithInMemory(services, _dbName);
                    ReplaceCacheWith(services, Cache);
                    services.RemoveAll<IHostedService>();
                });
            }
        }

        /// <summary>
        /// Factory with an empty cache (no data pre-loaded), forcing DB fallback.
        /// </summary>
        private sealed class CacheMissFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "CacheMissTest_" + Guid.NewGuid();

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");
                builder.ConfigureServices(services =>
                {
                    ReplaceDbWithInMemory(services, _dbName);
                    ReplaceCacheWith(services, new InMemoryCacheService());
                    services.RemoveAll<IHostedService>();
                });
            }
        }

        /// <summary>
        /// Factory with a failing cache (simulates Redis down), forcing DB fallback.
        /// </summary>
        private sealed class CacheDownFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "CacheDownTest_" + Guid.NewGuid();

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");
                builder.ConfigureServices(services =>
                {
                    ReplaceDbWithInMemory(services, _dbName);

                    // Wrap the failing cache in ResilientCacheService, matching production DI
                    ICacheService resilient = new ResilientCacheService(
                        new FailingCacheService(),
                        NullLogger<ResilientCacheService>.Instance);
                    ReplaceCacheWith(services, resilient);

                    services.RemoveAll<IHostedService>();
                });
            }
        }

        [Fact]
        public async Task GetEvents_WhenCacheHasData_ReturnsCachedEvents_WithCacheHitTrue()
        {
            using CacheHitFactory factory = new();

            // Pre-populate cache with serialized event data
            Event testEvent = CreateTestEvent("cached-event");
            string serialized = JsonSerializer.Serialize(
                new List<Event> { testEvent }, JsonOptions);
            await factory.Cache.SetAsync(CacheKeys.EventsAll, serialized);

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.True(eventsResponse.CacheHit, "Response should indicate cache hit");
            Assert.NotEmpty(eventsResponse.Events);
        }

        [Fact]
        public async Task GetEvents_WhenCacheEmpty_FallsBackToDb_WithCacheHitFalse()
        {
            using CacheMissFactory factory = new();

            // Seed database only — cache is empty
            Event testEvent = CreateTestEvent("db-fallback-event");
            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(testEvent);
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.False(eventsResponse.CacheHit, "Response should indicate cache miss (DB fallback)");
            Assert.NotEmpty(eventsResponse.Events);

            EventDto returnedEvent = Assert.Single(eventsResponse.Events);
            Assert.Equal("db-fallback-event", returnedEvent.Id);
            Assert.Equal("Community Day: Charmander", returnedEvent.Name);
        }

        [Fact]
        public async Task GetEvents_WhenRedisDown_FallsBackToDb_ReturnsEvents()
        {
            using CacheDownFactory factory = new();

            // Seed database — cache will throw on every call
            Event testEvent = CreateTestEvent("redis-down-event");
            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(testEvent);
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.False(eventsResponse.CacheHit, "Response should indicate cache miss when Redis is down");
            Assert.NotEmpty(eventsResponse.Events);

            EventDto returnedEvent = Assert.Single(eventsResponse.Events);
            Assert.Equal("redis-down-event", returnedEvent.Id);
        }

        [Fact]
        public async Task GetEvents_WhenRedisDown_AndDbHasNoEvents_ReturnsEmptyList()
        {
            using CacheDownFactory factory = new();

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.Empty(eventsResponse.Events);
        }

        [Fact]
        public async Task GetEvents_CacheHit_SkipsDatabase_ReturnsCachedData()
        {
            using CacheHitFactory factory = new();

            // Put data in cache but NOT in database — proves cache is the source
            Event cachedEvent = CreateTestEvent("cache-only-event");
            string serialized = JsonSerializer.Serialize(
                new List<Event> { cachedEvent }, JsonOptions);
            await factory.Cache.SetAsync(CacheKeys.EventsAll, serialized);

            // Database is empty — if the endpoint hits DB it would return nothing
            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.True(eventsResponse.CacheHit);
            Assert.NotEmpty(eventsResponse.Events);
        }

        #region Test Doubles

        private sealed class InMemoryCacheService : ICacheService
        {
            private readonly Dictionary<string, string> _store = [];

            public Task<string?> GetAsync(string key)
            {
                _store.TryGetValue(key, out string? value);
                return Task.FromResult(value);
            }

            public Task SetAsync(string key, string value, TimeSpan? ttl = null)
            {
                _store[key] = value;
                return Task.CompletedTask;
            }

            public Task InvalidateAsync(string key)
            {
                _store.Remove(key);
                return Task.CompletedTask;
            }
        }

        /// <summary>
        /// Simulates Redis being completely unavailable — all operations throw.
        /// The ResilientCacheService wrapper should catch these and return null,
        /// triggering the DB fallback path.
        /// </summary>
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
