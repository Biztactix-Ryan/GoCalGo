using System.Net;
using System.Text.Json;
using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using GoCalGo.Contracts.Events;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;

namespace GoCalGo.Api.Tests.Api
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-5:
    /// "GET endpoint returns upcoming events within a configurable window"
    ///
    /// Tests the GET /api/events/upcoming endpoint with a ?days= query parameter
    /// that controls how far ahead to look for upcoming events.
    /// </summary>
    public class UpcomingEventsWindowTests : IAsyncLifetime, IDisposable
    {
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
        };

        private readonly TestFactory _factory = new();

        public void Dispose()
        {
            _factory.Dispose();
            GC.SuppressFinalize(this);
        }

        public class TestFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "UpcomingEventsTest_" + Guid.NewGuid();

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");

                builder.ConfigureServices(services =>
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
                        options.UseInMemoryDatabase(_dbName));

                    services.RemoveAll<StackExchange.Redis.IConnectionMultiplexer>();
                    services.RemoveAll<RedisCacheService>();
                    services.RemoveAll<ICacheService>();
                    services.AddSingleton<ICacheService>(new InMemoryCacheService());

                    services.RemoveAll<IHostedService>();
                });
            }
        }

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

        private DateTime _now;

        public async Task InitializeAsync()
        {
            _now = DateTime.UtcNow;

            // Seed events at various time offsets for testing the window
            Event pastEvent = new()
            {
                Id = "past-event",
                Name = "Past Community Day",
                EventType = EventType.CommunityDay,
                Heading = "Already over",
                ImageUrl = "https://example.com/past.png",
                LinkUrl = "https://example.com/past",
                Start = _now.AddDays(-3),
                End = _now.AddDays(-2),
                IsUtcTime = true,
                HasSpawns = false,
                HasResearchTasks = false,
                Buffs = [],
            };

            Event activeNowEvent = new()
            {
                Id = "active-now-event",
                Name = "Currently Active Raid Hour",
                EventType = EventType.RaidHour,
                Heading = "Happening now",
                ImageUrl = "https://example.com/active.png",
                LinkUrl = "https://example.com/active",
                Start = _now.AddHours(-1),
                End = _now.AddHours(1),
                IsUtcTime = true,
                HasSpawns = true,
                HasResearchTasks = false,
                Buffs = [],
            };

            Event upcomingTomorrowEvent = new()
            {
                Id = "upcoming-tomorrow",
                Name = "Tomorrow's Spotlight Hour",
                EventType = EventType.SpotlightHour,
                Heading = "Coming tomorrow",
                ImageUrl = "https://example.com/tomorrow.png",
                LinkUrl = "https://example.com/tomorrow",
                Start = _now.AddDays(1),
                End = _now.AddDays(1).AddHours(1),
                IsUtcTime = true,
                HasSpawns = true,
                HasResearchTasks = false,
                Buffs = [],
            };

            Event upcomingIn5DaysEvent = new()
            {
                Id = "upcoming-5-days",
                Name = "Weekend GO Fest",
                EventType = EventType.PokemonGoFest,
                Heading = "Coming in 5 days",
                ImageUrl = "https://example.com/gofest.png",
                LinkUrl = "https://example.com/gofest",
                Start = _now.AddDays(5),
                End = _now.AddDays(6),
                IsUtcTime = true,
                HasSpawns = true,
                HasResearchTasks = true,
                Buffs =
                [
                    new EventBuff
                    {
                        Text = "2× Catch XP",
                        Category = Models.BuffCategory.Multiplier,
                        Multiplier = 2.0,
                        Resource = "XP",
                    },
                ],
            };

            Event upcomingIn14DaysEvent = new()
            {
                Id = "upcoming-14-days",
                Name = "Safari Zone Far Future",
                EventType = EventType.SafariZone,
                Heading = "Coming in two weeks",
                ImageUrl = "https://example.com/safari.png",
                LinkUrl = "https://example.com/safari",
                Start = _now.AddDays(14),
                End = _now.AddDays(15),
                IsUtcTime = true,
                HasSpawns = true,
                HasResearchTasks = false,
                Buffs = [],
            };

            using IServiceScope scope = _factory.Services.CreateScope();
            GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
            db.Events.AddRange(pastEvent, activeNowEvent, upcomingTomorrowEvent,
                upcomingIn5DaysEvent, upcomingIn14DaysEvent);
            await db.SaveChangesAsync();
        }

        public Task DisposeAsync()
        {
            _factory.Dispose();
            return Task.CompletedTask;
        }

        [Fact]
        public async Task GetUpcoming_DefaultWindow_ReturnsUpcomingEventsWithin7Days()
        {
            // Act: no ?days= parameter — should use default window (7 days)
            HttpClient client = _factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/upcoming");

            // Assert
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);

            List<string> returnedIds = [.. eventsResponse.Events.Select(e => e.Id)];

            // Should include events starting within the next 7 days
            Assert.Contains("upcoming-tomorrow", returnedIds);
            Assert.Contains("upcoming-5-days", returnedIds);

            // Should NOT include past events
            Assert.DoesNotContain("past-event", returnedIds);

            // Should NOT include events beyond the 7-day window
            Assert.DoesNotContain("upcoming-14-days", returnedIds);
        }

        [Fact]
        public async Task GetUpcoming_ExcludesCurrentlyActiveEvents()
        {
            // Upcoming endpoint should only return events that haven't started yet
            HttpClient client = _factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/upcoming");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);

            List<string> returnedIds = [.. eventsResponse.Events.Select(e => e.Id)];

            // Currently active event should not appear in upcoming
            Assert.DoesNotContain("active-now-event", returnedIds);
        }

        [Fact]
        public async Task GetUpcoming_CustomWindow_3Days_ReturnsOnlyEventsWithin3Days()
        {
            // Act: request a 3-day window
            HttpClient client = _factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/upcoming?days=3");

            // Assert
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);

            List<string> returnedIds = [.. eventsResponse.Events.Select(e => e.Id)];

            // Tomorrow's event is within 3 days
            Assert.Contains("upcoming-tomorrow", returnedIds);

            // 5-day and 14-day events are outside the 3-day window
            Assert.DoesNotContain("upcoming-5-days", returnedIds);
            Assert.DoesNotContain("upcoming-14-days", returnedIds);
        }

        [Fact]
        public async Task GetUpcoming_CustomWindow_30Days_ReturnsAllUpcomingEvents()
        {
            // Act: request a 30-day window that captures everything
            HttpClient client = _factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/upcoming?days=30");

            // Assert
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);

            List<string> returnedIds = [.. eventsResponse.Events.Select(e => e.Id)];

            // All future events should be included
            Assert.Contains("upcoming-tomorrow", returnedIds);
            Assert.Contains("upcoming-5-days", returnedIds);
            Assert.Contains("upcoming-14-days", returnedIds);

            // Past and active events still excluded
            Assert.DoesNotContain("past-event", returnedIds);
            Assert.DoesNotContain("active-now-event", returnedIds);
        }

        [Fact]
        public async Task GetUpcoming_UpcomingEventsIncludeBuffs()
        {
            // The 5-day event has buffs — verify they come through
            HttpClient client = _factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/upcoming?days=7");

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);

            EventDto goFest = Assert.Single(eventsResponse.Events,
                e => e.Id == "upcoming-5-days");

            Assert.Single(goFest.Buffs);
            Assert.Equal("2× Catch XP", goFest.Buffs[0].Text);
            Assert.Equal(Contracts.Events.BuffCategory.Multiplier, goFest.Buffs[0].Category);
            Assert.Equal(2.0, goFest.Buffs[0].Multiplier);
        }

        [Fact]
        public async Task GetUpcoming_ResultsAreOrderedByStartTime()
        {
            // Act: wide window to get multiple events
            HttpClient client = _factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/upcoming?days=30");

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.True(eventsResponse.Events.Count >= 2,
                "Expected at least 2 upcoming events for ordering check");

            // Verify events are sorted by start time ascending
            for (int i = 1; i < eventsResponse.Events.Count; i++)
            {
                Assert.True(
                    eventsResponse.Events[i].Start >= eventsResponse.Events[i - 1].Start,
                    $"Events not ordered by start time: '{eventsResponse.Events[i - 1].Name}' " +
                    $"(start={eventsResponse.Events[i - 1].Start}) should come before " +
                    $"'{eventsResponse.Events[i].Name}' (start={eventsResponse.Events[i].Start})");
            }
        }

        [Fact]
        public async Task GetUpcoming_ResponseShape_MatchesEventsResponseContract()
        {
            HttpClient client = _factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/upcoming");

            string json = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(json);
            JsonElement root = doc.RootElement;

            // Same envelope as /api/events
            Assert.True(root.TryGetProperty("events", out _));
            Assert.True(root.TryGetProperty("lastUpdated", out _));
            Assert.True(root.TryGetProperty("cacheHit", out _));
        }

        [Fact]
        public async Task GetUpcoming_InvalidDaysParam_ReturnsBadRequest()
        {
            HttpClient client = _factory.CreateClient();

            // Negative days should be rejected
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/upcoming?days=-1");
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }

        [Fact]
        public async Task GetUpcoming_ZeroDaysWindow_ReturnsEmpty()
        {
            HttpClient client = _factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events/upcoming?days=0");

            // Zero-day window means no upcoming events qualify
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.Empty(eventsResponse.Events);
        }
    }
}
