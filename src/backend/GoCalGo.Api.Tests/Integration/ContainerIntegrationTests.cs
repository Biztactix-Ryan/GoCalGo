using System.Net;
using System.Text.Json;
using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using GoCalGo.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace GoCalGo.Api.Tests.Integration
{
    /// <summary>
    /// Integration tests using WebApplicationFactory with Testcontainers
    /// for real PostgreSQL and Redis instances. Validates the full request pipeline
    /// against actual infrastructure rather than in-memory substitutes.
    /// </summary>
    [Collection(IntegrationTestDefinition.Name)]
    public class ContainerIntegrationTests(PostgresRedisFixture fixture) : IAsyncLifetime, IDisposable
    {
        private static readonly JsonSerializerOptions s_camelCase = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        };

        private IntegrationTestFactory _factory = null!;
        private HttpClient _client = null!;

        public async Task InitializeAsync()
        {
            _factory = new IntegrationTestFactory(fixture);
            _client = _factory.CreateClient();
            await _factory.EnsureDatabaseMigratedAsync();
        }

        public Task DisposeAsync()
        {
            return Task.CompletedTask;
        }

        public void Dispose()
        {
            _client?.Dispose();
            _factory?.Dispose();
            GC.SuppressFinalize(this);
        }

        [Fact]
        public async Task HealthEndpoint_ReportsHealthyDatabase_WithRealPostgres()
        {
            HttpResponseMessage response = await _client.GetAsync("/health");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            JsonDocument doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            string dbStatus = doc.RootElement
                .GetProperty("subsystems")
                .GetProperty("database")
                .GetProperty("status")
                .GetString()!;
            Assert.Equal("healthy", dbStatus);
        }

        [Fact]
        public async Task HealthEndpoint_ReportsHealthyRedis_WithRealRedis()
        {
            HttpResponseMessage response = await _client.GetAsync("/health");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            JsonDocument doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            string redisStatus = doc.RootElement
                .GetProperty("subsystems")
                .GetProperty("redis")
                .GetProperty("status")
                .GetString()!;
            Assert.Equal("healthy", redisStatus);
        }

        [Fact]
        public async Task EventsEndpoint_ReturnsEventsFromPostgres()
        {
            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                ICacheService cache = scope.ServiceProvider.GetRequiredService<ICacheService>();
                await cache.InvalidateAsync(CacheKeys.EventsAll);

                db.Events.Add(new Event
                {
                    Id = "integration-test-1",
                    Name = "Integration Test Community Day",
                    EventType = EventType.CommunityDay,
                    Heading = "Test heading",
                    ImageUrl = "https://example.com/test.png",
                    LinkUrl = "https://example.com/test",
                    Start = DateTime.UtcNow.AddHours(-1),
                    End = DateTime.UtcNow.AddHours(2),
                    Buffs =
                    [
                        new EventBuff
                        {
                            EventId = "integration-test-1",
                            Text = "3× Catch Stardust",
                            Category = BuffCategory.Multiplier,
                            Multiplier = 3.0,
                            Resource = "Catch Stardust",
                        },
                    ],
                });
                await db.SaveChangesAsync();
            }

            HttpResponseMessage response = await _client.GetAsync("/api/v1/events");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);
            JsonElement events = doc.RootElement.GetProperty("events");
            Assert.True(events.GetArrayLength() > 0, "Should return events from real PostgreSQL");

            bool found = false;
            for (int i = 0; i < events.GetArrayLength(); i++)
            {
                if (events[i].GetProperty("name").GetString() == "Integration Test Community Day")
                {
                    found = true;
                    break;
                }
            }
            Assert.True(found, "Should find the seeded event in the response");
        }

        [Fact]
        public async Task CacheAsidePattern_WorksWithRealRedis()
        {
            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                ICacheService cache = scope.ServiceProvider.GetRequiredService<ICacheService>();
                await cache.InvalidateAsync(CacheKeys.EventsAll);

                if (!await db.Events.AnyAsync(e => e.Id == "cache-test-1"))
                {
                    db.Events.Add(new Event
                    {
                        Id = "cache-test-1",
                        Name = "Cache Test Event",
                        EventType = EventType.Event,
                        Heading = "Cache test",
                        ImageUrl = "https://example.com/cache.png",
                        LinkUrl = "https://example.com/cache",
                    });
                    await db.SaveChangesAsync();
                }
            }

            // First request: cache miss, hits database
            HttpResponseMessage response1 = await _client.GetAsync("/api/v1/events");
            string content1 = await response1.Content.ReadAsStringAsync();
            JsonDocument doc1 = JsonDocument.Parse(content1);
            bool cacheHit1 = doc1.RootElement.GetProperty("cacheHit").GetBoolean();
            Assert.False(cacheHit1, "First request should be a cache miss");

            // Populate cache via Redis
            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                ICacheService cache = scope.ServiceProvider.GetRequiredService<ICacheService>();
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                List<Event> events = await db.Events.Include(e => e.Buffs).ToListAsync();
                string json = JsonSerializer.Serialize(events, s_camelCase);
                await cache.SetAsync(CacheKeys.EventsAll, json, TimeSpan.FromMinutes(5));
            }

            // Second request: cache hit from real Redis
            HttpResponseMessage response2 = await _client.GetAsync("/api/v1/events");
            string content2 = await response2.Content.ReadAsStringAsync();
            JsonDocument doc2 = JsonDocument.Parse(content2);
            bool cacheHit2 = doc2.RootElement.GetProperty("cacheHit").GetBoolean();
            Assert.True(cacheHit2, "Second request should be a cache hit from real Redis");
        }

        [Fact]
        public async Task Database_PersistsEventsWithBuffs_ViaRealPostgres()
        {
            string eventId = $"persist-test-{Guid.NewGuid():N}";

            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(new Event
                {
                    Id = eventId,
                    Name = "Persist Test Event",
                    EventType = EventType.RaidHour,
                    Heading = "Raid Hour",
                    ImageUrl = "https://example.com/raid.png",
                    LinkUrl = "https://example.com/raid",
                    Start = new DateTime(2026, 4, 1, 18, 0, 0, DateTimeKind.Utc),
                    End = new DateTime(2026, 4, 1, 19, 0, 0, DateTimeKind.Utc),
                    Buffs =
                    [
                        new EventBuff
                        {
                            EventId = eventId,
                            Text = "5-star Raid Bosses in all Gyms",
                            Category = BuffCategory.Spawn,
                        },
                    ],
                });
                await db.SaveChangesAsync();
            }

            // Read back from a fresh scope to verify real persistence
            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                Event? stored = await db.Events
                    .Include(e => e.Buffs)
                    .FirstOrDefaultAsync(e => e.Id == eventId);

                Assert.NotNull(stored);
                Assert.Equal("Persist Test Event", stored.Name);
                Assert.Equal(EventType.RaidHour, stored.EventType);
                Assert.Single(stored.Buffs);
                Assert.Equal("5-star Raid Bosses in all Gyms", stored.Buffs[0].Text);
            }
        }

        [Fact]
        public async Task RedisCache_StoresAndRetrievesValues()
        {
            using IServiceScope scope = _factory.Services.CreateScope();
            ICacheService cache = scope.ServiceProvider.GetRequiredService<ICacheService>();

            string key = $"test:{Guid.NewGuid():N}";
            await cache.SetAsync(key, "hello-from-redis", TimeSpan.FromMinutes(1));

            string? value = await cache.GetAsync(key);
            Assert.Equal("hello-from-redis", value);
        }

        [Fact]
        public async Task Migrations_ApplyCleanly_OnRealPostgres()
        {
            using IServiceScope scope = _factory.Services.CreateScope();
            GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();

            bool canConnect = await db.Database.CanConnectAsync();
            Assert.True(canConnect, "Should connect to real PostgreSQL container");

            // Verify tables exist by querying them
            List<Event> events = await db.Events.Take(1).ToListAsync();
            Assert.NotNull(events);
        }

        [Fact]
        public async Task ActiveEventsEndpoint_FiltersCorrectly_WithRealPostgres()
        {
            string activeId = $"active-{Guid.NewGuid():N}";
            string pastId = $"past-{Guid.NewGuid():N}";

            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                ICacheService cache = scope.ServiceProvider.GetRequiredService<ICacheService>();
                await cache.InvalidateAsync(CacheKeys.EventsAll);

                db.Events.AddRange(
                    new Event
                    {
                        Id = activeId,
                        Name = "Currently Active Event",
                        EventType = EventType.Event,
                        Heading = "Active",
                        ImageUrl = "https://example.com/active.png",
                        LinkUrl = "https://example.com/active",
                        Start = DateTime.UtcNow.AddHours(-1),
                        End = DateTime.UtcNow.AddHours(2),
                    },
                    new Event
                    {
                        Id = pastId,
                        Name = "Already Ended Event",
                        EventType = EventType.Event,
                        Heading = "Past",
                        ImageUrl = "https://example.com/past.png",
                        LinkUrl = "https://example.com/past",
                        Start = DateTime.UtcNow.AddDays(-3),
                        End = DateTime.UtcNow.AddDays(-2),
                    });
                await db.SaveChangesAsync();
            }

            HttpResponseMessage response = await _client.GetAsync("/api/v1/events/active");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            string content = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(content);
            JsonElement events = doc.RootElement.GetProperty("events");

            bool hasActive = false;
            bool hasPast = false;
            for (int i = 0; i < events.GetArrayLength(); i++)
            {
                string? name = events[i].GetProperty("name").GetString();
                if (name == "Currently Active Event")
                {
                    hasActive = true;
                }

                if (name == "Already Ended Event")
                {
                    hasPast = true;
                }
            }
            Assert.True(hasActive, "Active event should appear in /events/active response");
            Assert.False(hasPast, "Past event should not appear in /events/active response");
        }
    }
}
