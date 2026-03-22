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
using ModelBuffCategory = GoCalGo.Api.Models.BuffCategory;
using ContractBuffCategory = GoCalGo.Contracts.Events.BuffCategory;

namespace GoCalGo.Api.Tests.Api
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-5:
    /// "GET endpoint returns today's active events with buffs and bonuses"
    ///
    /// Seeds an in-memory database with active events including buffs, then
    /// asserts the GET /api/events response contains events with their buffs
    /// correctly mapped to the contract DTOs.
    /// </summary>
    public class ActiveEventsWithBuffsTests(ActiveEventsWithBuffsTests.TestFactory factory)
        : IClassFixture<ActiveEventsWithBuffsTests.TestFactory>
    {
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
        };

        /// <summary>
        /// Custom WebApplicationFactory that replaces Redis and PostgreSQL with
        /// in-memory test doubles so the test runs without infrastructure.
        /// </summary>
        public class TestFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "ActiveEventsTest_" + Guid.NewGuid();

            protected override void ConfigureWebHost(IWebHostBuilder builder)
            {
                builder.UseEnvironment("Testing");

                builder.ConfigureServices(services =>
                {
                    // Remove all EF Core / DbContext registrations (including Npgsql provider)
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

                    // Remove the real Redis connection and cache services
                    services.RemoveAll<StackExchange.Redis.IConnectionMultiplexer>();
                    services.RemoveAll<RedisCacheService>();
                    services.RemoveAll<ICacheService>();
                    services.AddSingleton<ICacheService>(new InMemoryCacheService());

                    // Remove the background ingestion job so it doesn't interfere
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

        [Fact]
        public async Task GetEvents_ReturnsActiveEventsWithBuffs()
        {
            // Arrange: seed DB with an active event that has buffs
            DateTime now = DateTime.UtcNow;
            Event activeEvent = new()
            {
                Id = "active-community-day",
                Name = "Community Day: Bulbasaur",
                EventType = EventType.CommunityDay,
                Heading = "Catch Bulbasaur!",
                ImageUrl = "https://example.com/bulbasaur.png",
                LinkUrl = "https://example.com/community-day",
                Start = now.AddHours(-2),
                End = now.AddHours(4),
                IsUtcTime = true,
                HasSpawns = true,
                HasResearchTasks = true,
                Buffs =
                [
                    new EventBuff
                    {
                        Text = "2× Catch Stardust",
                        IconUrl = "https://example.com/stardust.png",
                        Category = ModelBuffCategory.Multiplier,
                        Multiplier = 2.0,
                        Resource = "Stardust",
                    },
                    new EventBuff
                    {
                        Text = "3-hour Incense",
                        IconUrl = "https://example.com/incense.png",
                        Category = ModelBuffCategory.Duration,
                        Resource = "Incense",
                    },
                ],
            };

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(activeEvent);
                await db.SaveChangesAsync();
            }

            // Act
            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            // Assert
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.NotEmpty(eventsResponse.Events);

            EventDto returnedEvent = Assert.Single(eventsResponse.Events,
                e => e.Id == "active-community-day");

            Assert.Equal("Community Day: Bulbasaur", returnedEvent.Name);
            Assert.Equal(EventTypeDto.CommunityDay, returnedEvent.EventType);
            Assert.True(returnedEvent.HasSpawns);
            Assert.True(returnedEvent.HasResearchTasks);

            // Verify buffs are included
            Assert.Equal(2, returnedEvent.Buffs.Count);

            BuffDto stardustBuff = Assert.Single(returnedEvent.Buffs,
                b => b.Resource == "Stardust");
            Assert.Equal("2× Catch Stardust", stardustBuff.Text);
            Assert.Equal(ContractBuffCategory.Multiplier, stardustBuff.Category);
            Assert.Equal(2.0, stardustBuff.Multiplier);

            BuffDto incenseBuff = Assert.Single(returnedEvent.Buffs,
                b => b.Resource == "Incense");
            Assert.Equal("3-hour Incense", incenseBuff.Text);
            Assert.Equal(ContractBuffCategory.Duration, incenseBuff.Category);
        }

        [Fact]
        public async Task GetEvents_ResponseIncludesBuffIconUrls()
        {
            // Arrange
            DateTime now = DateTime.UtcNow;
            Event eventWithIcons = new()
            {
                Id = "event-with-buff-icons",
                Name = "Spotlight Hour",
                EventType = EventType.SpotlightHour,
                Heading = "Spotlight!",
                ImageUrl = "https://example.com/spotlight.png",
                LinkUrl = "https://example.com/spotlight",
                Start = now.AddMinutes(-30),
                End = now.AddMinutes(30),
                IsUtcTime = true,
                HasSpawns = true,
                HasResearchTasks = false,
                Buffs =
                [
                    new EventBuff
                    {
                        Text = "2× Transfer Candy",
                        IconUrl = "https://example.com/candy.png",
                        Category = ModelBuffCategory.Multiplier,
                        Multiplier = 2.0,
                        Resource = "Candy",
                    },
                ],
            };

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(eventWithIcons);
                await db.SaveChangesAsync();
            }

            // Act
            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");
            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            // Assert: buff icon URLs are present in response
            Assert.NotNull(eventsResponse);
            EventDto returnedEvent = Assert.Single(eventsResponse.Events,
                e => e.Id == "event-with-buff-icons");

            BuffDto buff = Assert.Single(returnedEvent.Buffs);
            Assert.Equal("https://example.com/candy.png", buff.IconUrl);
        }

        [Fact]
        public async Task GetEvents_EventWithMultipleBuffCategories_AllCategoriesReturned()
        {
            // Arrange: event with buffs spanning different categories
            DateTime now = DateTime.UtcNow;
            Event multiBuffEvent = new()
            {
                Id = "multi-buff-event",
                Name = "GO Fest 2026",
                EventType = EventType.PokemonGoFest,
                Heading = "GO Fest!",
                ImageUrl = "https://example.com/gofest.png",
                LinkUrl = "https://example.com/gofest",
                Start = now.AddDays(-1),
                End = now.AddDays(1),
                IsUtcTime = true,
                HasSpawns = true,
                HasResearchTasks = true,
                Buffs =
                [
                    new EventBuff
                    {
                        Text = "2× Catch XP",
                        Category = ModelBuffCategory.Multiplier,
                        Multiplier = 2.0,
                        Resource = "XP",
                    },
                    new EventBuff
                    {
                        Text = "Increased Shiny rate",
                        Category = ModelBuffCategory.Probability,
                    },
                    new EventBuff
                    {
                        Text = "1 extra Special Trade",
                        Category = ModelBuffCategory.Trade,
                    },
                    new EventBuff
                    {
                        Text = "Increased wild spawns",
                        Category = ModelBuffCategory.Spawn,
                    },
                ],
            };

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(multiBuffEvent);
                await db.SaveChangesAsync();
            }

            // Act
            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");
            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            // Assert: all buff categories are present
            Assert.NotNull(eventsResponse);
            EventDto returnedEvent = Assert.Single(eventsResponse.Events,
                e => e.Id == "multi-buff-event");

            Assert.Equal(4, returnedEvent.Buffs.Count);

            HashSet<ContractBuffCategory> categories = [.. returnedEvent.Buffs.Select(b => b.Category)];
            Assert.Contains(ContractBuffCategory.Multiplier, categories);
            Assert.Contains(ContractBuffCategory.Probability, categories);
            Assert.Contains(ContractBuffCategory.Trade, categories);
            Assert.Contains(ContractBuffCategory.Spawn, categories);
        }

        [Fact]
        public async Task GetEvents_ReturnsOkWithEmptyList_WhenNoEvents()
        {
            // Use a separate factory to get a clean database
            using TestFactory cleanFactory = new();
            HttpClient client = cleanFactory.CreateClient();

            HttpResponseMessage response = await client.GetAsync("/api/v1/events");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            EventsResponse? eventsResponse = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions);

            Assert.NotNull(eventsResponse);
            Assert.Empty(eventsResponse.Events);
        }

        [Fact]
        public async Task GetEvents_ResponseShape_MatchesEventDtoContract()
        {
            // Arrange
            DateTime now = DateTime.UtcNow;
            Event ev = new()
            {
                Id = "shape-test-event",
                Name = "Raid Hour",
                EventType = EventType.RaidHour,
                Heading = "Raid Hour!",
                ImageUrl = "https://example.com/raid.png",
                LinkUrl = "https://example.com/raid",
                Start = now.AddHours(-1),
                End = now.AddHours(1),
                IsUtcTime = true,
                HasSpawns = false,
                HasResearchTasks = false,
                Buffs =
                [
                    new EventBuff
                    {
                        Text = "Extra Raid Pass",
                        Category = ModelBuffCategory.Other,
                        Disclaimer = "Up to 5 free passes",
                    },
                ],
            };

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.Add(ev);
                await db.SaveChangesAsync();
            }

            // Act
            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");
            string json = await response.Content.ReadAsStringAsync();

            // Assert: verify raw JSON shape has expected top-level keys
            JsonDocument doc = JsonDocument.Parse(json);
            JsonElement root = doc.RootElement;

            Assert.True(root.TryGetProperty("events", out _));
            Assert.True(root.TryGetProperty("lastUpdated", out _));
            Assert.True(root.TryGetProperty("cacheHit", out _));

            // Verify event properties in JSON
            JsonElement eventsArray = root.GetProperty("events");
            JsonElement eventJson = eventsArray.EnumerateArray()
                .First(e => e.GetProperty("id").GetString() == "shape-test-event");

            Assert.True(eventJson.TryGetProperty("id", out _));
            Assert.True(eventJson.TryGetProperty("name", out _));
            Assert.True(eventJson.TryGetProperty("eventType", out _));
            Assert.True(eventJson.TryGetProperty("buffs", out _));
            Assert.True(eventJson.TryGetProperty("hasSpawns", out _));
            Assert.True(eventJson.TryGetProperty("hasResearchTasks", out _));

            // Verify buff includes disclaimer field
            JsonElement buffsArray = eventJson.GetProperty("buffs");
            JsonElement buffJson = buffsArray.EnumerateArray().First();
            Assert.Equal("Up to 5 free passes", buffJson.GetProperty("disclaimer").GetString());
        }
    }
}
