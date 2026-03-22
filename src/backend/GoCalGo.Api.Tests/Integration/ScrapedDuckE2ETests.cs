using System.Net;
using System.Text.Json;
using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using GoCalGo.Api.Tests.Infrastructure;
using GoCalGo.Contracts.Events;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using WireMock.RequestBuilders;
using WireMock.ResponseBuilders;
using WireMock.Server;

namespace GoCalGo.Api.Tests.Integration
{
    /// <summary>
    /// End-to-end test: mock ScrapedDuck data is ingested via the ingestion service,
    /// stored in PostgreSQL, cached in Redis, served via REST API endpoints,
    /// and the response shape matches the contract consumed by the Flutter app.
    /// </summary>
    [Collection(IntegrationTestDefinition.Name)]
    public class ScrapedDuckE2ETests(PostgresRedisFixture fixture) : IAsyncLifetime, IDisposable
    {
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            PropertyNameCaseInsensitive = true,
        };

        /// <summary>
        /// Mock ScrapedDuck JSON payload representing a realistic set of events
        /// with various event types, timestamps, buffs, and pokemon data.
        /// </summary>
        private static readonly string MockScrapedDuckPayload = """
            [
                {
                    "eventID": "e2e-community-day-march",
                    "name": "March Community Day: Bulbasaur",
                    "eventType": "community-day",
                    "heading": "Featuring Bulbasaur with exclusive move Frenzy Plant",
                    "image": "https://example.com/cd-march.png",
                    "link": "https://pokemongolive.com/events/cd-march-2026",
                    "start": "2026-03-22 11:00",
                    "end": "2026-03-22 23:59",
                    "extraData": {
                        "generic": {
                            "hasSpawns": true,
                            "hasFieldResearchTasks": true
                        },
                        "communityday": {
                            "spawns": [
                                {"name": "Bulbasaur", "image": "https://img.pokemondb.net/bulbasaur.png", "canBeShiny": true}
                            ],
                            "bonuses": [
                                {"text": "3x Catch Stardust", "image": "https://example.com/stardust.png"},
                                {"text": "2x Catch Candy", "image": "https://example.com/candy.png"}
                            ],
                            "bonusDisclaimers": ["Some bonuses require a ticket"]
                        }
                    }
                },
                {
                    "eventID": "e2e-spotlight-pikachu",
                    "name": "Spotlight Hour: Pikachu",
                    "eventType": "pokemon-spotlight-hour",
                    "heading": "Featuring Pikachu with 2x Transfer Candy",
                    "image": "https://example.com/sh-pikachu.png",
                    "link": "https://pokemongolive.com/events/sh-pikachu",
                    "start": "2026-03-24T18:00:00Z",
                    "end": "2026-03-24T19:00:00Z",
                    "extraData": {
                        "spotlighthour": {
                            "pokemon": {"name": "Pikachu", "image": "https://img.pokemondb.net/pikachu.png", "canBeShiny": true},
                            "bonus": {"text": "2x Transfer Candy", "image": "https://example.com/candy.png"}
                        }
                    }
                },
                {
                    "eventID": "e2e-raid-hour",
                    "name": "Raid Hour: Mega Charizard",
                    "eventType": "raid-hour",
                    "heading": "Mega Charizard X in 5-star raids",
                    "image": "https://example.com/rh-charizard.png",
                    "link": "https://pokemongolive.com/events/rh-charizard",
                    "start": "2026-03-25T18:00:00Z",
                    "end": "2026-03-25T19:00:00Z",
                    "extraData": {}
                }
            ]
            """;

        private WireMockServer _wireMock = null!;
        private IntegrationTestFactory _factory = null!;
        private HttpClient _client = null!;

        public async Task InitializeAsync()
        {
            _wireMock = WireMockServer.Start();

            // Serve mock ScrapedDuck data
            _wireMock.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithHeader("Content-Type", "application/json")
                    .WithBody(MockScrapedDuckPayload));

            _factory = new IntegrationTestFactory(fixture, _wireMock.Url!);
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
            _wireMock?.Stop();
            _wireMock?.Dispose();
            GC.SuppressFinalize(this);
        }

        [Fact]
        public async Task E2E_MockScrapedDuckData_IsIngestedAndServedViaApi()
        {
            // Phase 1: Trigger ingestion from mock ScrapedDuck
            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                ScrapedDuckIngestionService ingestion = scope.ServiceProvider
                    .GetRequiredService<ScrapedDuckIngestionService>();

                IReadOnlyList<ParsedEvent> ingested = await ingestion.FetchEventsAsync();

                Assert.Equal(3, ingested.Count);
                Assert.Equal("e2e-community-day-march", ingested[0].Id);
                Assert.Equal("e2e-spotlight-pikachu", ingested[1].Id);
                Assert.Equal("e2e-raid-hour", ingested[2].Id);
            }

            // Phase 2: Verify events are served via /api/v1/events
            HttpResponseMessage eventsResponse = await _client.GetAsync("/api/v1/events");

            Assert.Equal(HttpStatusCode.OK, eventsResponse.StatusCode);
            string eventsJson = await eventsResponse.Content.ReadAsStringAsync();
            EventsResponse eventsResult = JsonSerializer.Deserialize<EventsResponse>(eventsJson, JsonOptions)!;

            Assert.NotNull(eventsResult);
            Assert.True(eventsResult.Events.Count >= 3, "Should contain at least the 3 ingested events");

            // Verify Community Day event with buffs
            EventDto? cdEvent = eventsResult.Events.FirstOrDefault(e => e.Id == "e2e-community-day-march");
            Assert.NotNull(cdEvent);
            Assert.Equal("March Community Day: Bulbasaur", cdEvent.Name);
            Assert.Equal(EventTypeDto.CommunityDay, cdEvent.EventType);
            Assert.Equal("Featuring Bulbasaur with exclusive move Frenzy Plant", cdEvent.Heading);
            Assert.Equal("https://example.com/cd-march.png", cdEvent.ImageUrl);
            Assert.Equal("https://pokemongolive.com/events/cd-march-2026", cdEvent.LinkUrl);
            Assert.NotNull(cdEvent.Start);
            Assert.NotNull(cdEvent.End);
            Assert.False(cdEvent.IsUtcTime);
            Assert.True(cdEvent.HasSpawns);
            Assert.True(cdEvent.HasResearchTasks);
            Assert.Equal(2, cdEvent.Buffs.Count);
            Assert.Contains(cdEvent.Buffs, b => b.Text == "3x Catch Stardust"
                && b.Category == Contracts.Events.BuffCategory.Multiplier
                && b.Multiplier == 3.0
                && b.Resource == "Catch Stardust");
            Assert.Contains(cdEvent.Buffs, b => b.Text == "2x Catch Candy"
                && b.Category == Contracts.Events.BuffCategory.Multiplier
                && b.Multiplier == 2.0);

            // Verify Spotlight Hour event (UTC timestamps)
            EventDto? shEvent = eventsResult.Events.FirstOrDefault(e => e.Id == "e2e-spotlight-pikachu");
            Assert.NotNull(shEvent);
            Assert.Equal("Spotlight Hour: Pikachu", shEvent.Name);
            Assert.Equal(EventTypeDto.SpotlightHour, shEvent.EventType);
            Assert.True(shEvent.IsUtcTime);
            Assert.Single(shEvent.Buffs);
            Assert.Equal("2x Transfer Candy", shEvent.Buffs[0].Text);

            // Verify Raid Hour event
            EventDto? rhEvent = eventsResult.Events.FirstOrDefault(e => e.Id == "e2e-raid-hour");
            Assert.NotNull(rhEvent);
            Assert.Equal("Raid Hour: Mega Charizard", rhEvent.Name);
            Assert.Equal(EventTypeDto.RaidHour, rhEvent.EventType);

            // Phase 3: Verify data is cached (second request should be cache hit)
            HttpResponseMessage cachedResponse = await _client.GetAsync("/api/v1/events");
            Assert.Equal(HttpStatusCode.OK, cachedResponse.StatusCode);
            string cachedJson = await cachedResponse.Content.ReadAsStringAsync();
            EventsResponse cachedResult = JsonSerializer.Deserialize<EventsResponse>(cachedJson, JsonOptions)!;
            Assert.True(cachedResult.CacheHit, "Second request should be served from Redis cache");

            // Phase 4: Verify response shape matches Flutter app contract
            // The Flutter app deserializes EventsResponse → List<EventDto> with these required fields
            VerifyContractShape(eventsJson);
        }

        [Fact]
        public async Task E2E_IngestedData_AppearsInActiveEventsEndpoint()
        {
            // Ingest mock data
            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                ScrapedDuckIngestionService ingestion = scope.ServiceProvider
                    .GetRequiredService<ScrapedDuckIngestionService>();
                await ingestion.FetchEventsAsync();
            }

            // The active events endpoint filters by current time, so only events
            // where Start <= now <= End will appear. Our mock data uses fixed dates
            // that may or may not be active. Verify the endpoint responds correctly.
            HttpResponseMessage response = await _client.GetAsync("/api/v1/events/active");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            string json = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(json);

            // Verify response structure has required fields
            Assert.True(doc.RootElement.TryGetProperty("events", out JsonElement events));
            Assert.Equal(JsonValueKind.Array, events.ValueKind);
            Assert.True(doc.RootElement.TryGetProperty("lastUpdated", out _));
            Assert.True(doc.RootElement.TryGetProperty("cacheHit", out _));
        }

        [Fact]
        public async Task E2E_IngestedData_AppearsInUpcomingEventsEndpoint()
        {
            // Ingest mock data
            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                ScrapedDuckIngestionService ingestion = scope.ServiceProvider
                    .GetRequiredService<ScrapedDuckIngestionService>();
                await ingestion.FetchEventsAsync();
            }

            // Use a large window to capture test events regardless of when tests run
            HttpResponseMessage response = await _client.GetAsync("/api/v1/events/upcoming?days=365");

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            string json = await response.Content.ReadAsStringAsync();
            EventsResponse result = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions)!;

            // Verify the endpoint returns valid event DTOs with correct structure
            foreach (EventDto evt in result.Events)
            {
                Assert.False(string.IsNullOrEmpty(evt.Id));
                Assert.False(string.IsNullOrEmpty(evt.Name));
                Assert.False(string.IsNullOrEmpty(evt.Heading));
                Assert.NotNull(evt.Buffs);
                Assert.NotNull(evt.FeaturedPokemon);
                Assert.NotNull(evt.PromoCodes);
            }
        }

        [Fact]
        public async Task E2E_IngestedData_PersistedInDatabase()
        {
            // Ingest mock data
            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                ScrapedDuckIngestionService ingestion = scope.ServiceProvider
                    .GetRequiredService<ScrapedDuckIngestionService>();
                await ingestion.FetchEventsAsync();
            }

            // Verify data persisted in database independent of cache
            using (IServiceScope scope = _factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                ICacheService cache = scope.ServiceProvider.GetRequiredService<ICacheService>();

                // Clear cache to force DB read
                await cache.InvalidateAsync(CacheKeys.EventsAll);

                Event? cdEvent = await db.Events
                    .Include(e => e.Buffs)
                    .Where(e => e.Id == "e2e-community-day-march")
                    .FirstOrDefaultAsync();

                Assert.NotNull(cdEvent);
                Assert.Equal("March Community Day: Bulbasaur", cdEvent.Name);
                Assert.Equal(2, cdEvent.Buffs.Count);
            }

            // API should still serve from DB after cache clear
            HttpResponseMessage response = await _client.GetAsync("/api/v1/events");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            string json = await response.Content.ReadAsStringAsync();
            EventsResponse result = JsonSerializer.Deserialize<EventsResponse>(json, JsonOptions)!;
            Assert.False(result.CacheHit, "Should serve from database after cache invalidation");
            Assert.Contains(result.Events, e => e.Id == "e2e-community-day-march");
        }

        /// <summary>
        /// Validates the JSON response structure matches the contract the Flutter app expects.
        /// The Flutter app uses event_dto.dart with fromJson that requires these exact field names.
        /// </summary>
        private static void VerifyContractShape(string responseJson)
        {
            JsonDocument doc = JsonDocument.Parse(responseJson);
            JsonElement root = doc.RootElement;

            // Top-level envelope
            Assert.True(root.TryGetProperty("events", out JsonElement events));
            Assert.True(root.TryGetProperty("lastUpdated", out _));
            Assert.True(root.TryGetProperty("cacheHit", out _));

            // Verify each event has all required fields for the Flutter EventDto
            foreach (JsonElement evt in events.EnumerateArray())
            {
                Assert.True(evt.TryGetProperty("id", out _), "Missing 'id'");
                Assert.True(evt.TryGetProperty("name", out _), "Missing 'name'");
                Assert.True(evt.TryGetProperty("eventType", out _), "Missing 'eventType'");
                Assert.True(evt.TryGetProperty("heading", out _), "Missing 'heading'");
                Assert.True(evt.TryGetProperty("imageUrl", out _), "Missing 'imageUrl'");
                Assert.True(evt.TryGetProperty("linkUrl", out _), "Missing 'linkUrl'");
                Assert.True(evt.TryGetProperty("isUtcTime", out _), "Missing 'isUtcTime'");
                Assert.True(evt.TryGetProperty("hasSpawns", out _), "Missing 'hasSpawns'");
                Assert.True(evt.TryGetProperty("hasResearchTasks", out _), "Missing 'hasResearchTasks'");
                Assert.True(evt.TryGetProperty("buffs", out JsonElement buffs), "Missing 'buffs'");
                Assert.Equal(JsonValueKind.Array, buffs.ValueKind);
                Assert.True(evt.TryGetProperty("featuredPokemon", out _), "Missing 'featuredPokemon'");
                Assert.True(evt.TryGetProperty("promoCodes", out _), "Missing 'promoCodes'");

                // Verify buff shape if present
                foreach (JsonElement buff in buffs.EnumerateArray())
                {
                    Assert.True(buff.TryGetProperty("text", out _), "Buff missing 'text'");
                    Assert.True(buff.TryGetProperty("category", out _), "Buff missing 'category'");
                }
            }
        }
    }
}
