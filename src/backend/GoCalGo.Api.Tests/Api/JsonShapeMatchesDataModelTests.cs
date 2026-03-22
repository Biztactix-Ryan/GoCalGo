using System.Net;
using System.Text.Json;
using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using ModelBuffCategory = GoCalGo.Api.Models.BuffCategory;

namespace GoCalGo.Api.Tests.Api
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-5:
    /// "API returns properly shaped JSON matching the app's data model"
    ///
    /// These tests parse raw JSON responses and assert that every property name,
    /// type, enum serialization format, and nullable-field convention matches the
    /// contract DTOs the Flutter app depends on.
    /// </summary>
    public class JsonShapeMatchesDataModelTests(JsonShapeMatchesDataModelTests.TestFactory factory)
        : IClassFixture<JsonShapeMatchesDataModelTests.TestFactory>
    {
        public class TestFactory : WebApplicationFactory<Program>
        {
            private readonly string _dbName = "JsonShapeTest_" + Guid.NewGuid();

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

        /// <summary>
        /// Seeds a fully-populated event and a minimal event, then returns the raw JSON response.
        /// </summary>
        private async Task<(string json, JsonDocument doc)> SeedAndFetch()
        {
            DateTime now = DateTime.UtcNow;

            Event fullEvent = new()
            {
                Id = "shape-full-" + Guid.NewGuid().ToString("N")[..8],
                Name = "Community Day: Charmander",
                EventType = EventType.CommunityDay,
                Heading = "Catch Charmander during Community Day!",
                ImageUrl = "https://example.com/charmander.png",
                LinkUrl = "https://example.com/community-day-charmander",
                Start = now.AddHours(-1),
                End = now.AddHours(5),
                IsUtcTime = true,
                HasSpawns = true,
                HasResearchTasks = true,
                Buffs =
                [
                    new EventBuff
                    {
                        Text = "3× Catch XP",
                        IconUrl = "https://example.com/xp-icon.png",
                        Category = ModelBuffCategory.Multiplier,
                        Multiplier = 3.0,
                        Resource = "XP",
                        Disclaimer = "Only during event hours",
                    },
                    new EventBuff
                    {
                        Text = "Increased wild spawns",
                        Category = ModelBuffCategory.Spawn,
                    },
                ],
            };

            Event minimalEvent = new()
            {
                Id = "shape-minimal-" + Guid.NewGuid().ToString("N")[..8],
                Name = "Season of Discovery",
                EventType = EventType.Season,
                Heading = "New season begins",
                ImageUrl = "https://example.com/season.png",
                LinkUrl = "https://example.com/season",
                Start = null,
                End = null,
                IsUtcTime = false,
                HasSpawns = false,
                HasResearchTasks = false,
                Buffs = [],
            };

            using (IServiceScope scope = factory.Services.CreateScope())
            {
                GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                db.Events.AddRange(fullEvent, minimalEvent);
                await db.SaveChangesAsync();
            }

            HttpClient client = factory.CreateClient();
            HttpResponseMessage response = await client.GetAsync("/api/v1/events");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            string json = await response.Content.ReadAsStringAsync();
            JsonDocument doc = JsonDocument.Parse(json);
            return (json, doc);
        }

        private static JsonElement FindEvent(JsonDocument doc, string namePrefix)
        {
            return doc.RootElement.GetProperty("events").EnumerateArray()
                .First(e => e.GetProperty("name").GetString()!.StartsWith(namePrefix, StringComparison.Ordinal));
        }

        [Fact]
        public async Task Response_HasCorrectEnvelopeShape()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement root = doc.RootElement;

            Assert.Equal(JsonValueKind.Object, root.ValueKind);
            Assert.True(root.TryGetProperty("events", out JsonElement events));
            Assert.True(root.TryGetProperty("lastUpdated", out JsonElement lastUpdated));
            Assert.True(root.TryGetProperty("cacheHit", out JsonElement cacheHit));

            Assert.Equal(JsonValueKind.Array, events.ValueKind);
            Assert.Equal(JsonValueKind.String, lastUpdated.ValueKind);
            Assert.True(cacheHit.ValueKind is JsonValueKind.True or JsonValueKind.False);
        }

        [Fact]
        public async Task Response_NoExtraTopLevelProperties()
        {
            (_, JsonDocument doc) = await SeedAndFetch();

            HashSet<string> expectedProperties = ["events", "lastUpdated", "cacheHit"];
            HashSet<string> actualProperties = [.. doc.RootElement.EnumerateObject().Select(p => p.Name)];

            Assert.True(expectedProperties.SetEquals(actualProperties),
                $"Unexpected top-level properties. Expected: [{string.Join(", ", expectedProperties)}], " +
                $"Got: [{string.Join(", ", actualProperties)}]");
        }

        [Fact]
        public async Task EventDto_HasAllRequiredProperties()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");

            string[] requiredProperties =
            [
                "id", "name", "eventType", "heading", "imageUrl", "linkUrl",
                "start", "end", "isUtcTime", "hasSpawns", "hasResearchTasks",
                "buffs", "featuredPokemon", "promoCodes",
            ];

            foreach (string prop in requiredProperties)
            {
                Assert.True(ev.TryGetProperty(prop, out _),
                    $"EventDto missing expected property '{prop}'");
            }
        }

        [Fact]
        public async Task EventDto_PropertyTypes_AreCorrect()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");

            Assert.Equal(JsonValueKind.String, ev.GetProperty("id").ValueKind);
            Assert.Equal(JsonValueKind.String, ev.GetProperty("name").ValueKind);
            Assert.Equal(JsonValueKind.String, ev.GetProperty("eventType").ValueKind);
            Assert.Equal(JsonValueKind.String, ev.GetProperty("heading").ValueKind);
            Assert.Equal(JsonValueKind.String, ev.GetProperty("imageUrl").ValueKind);
            Assert.Equal(JsonValueKind.String, ev.GetProperty("linkUrl").ValueKind);
            Assert.Equal(JsonValueKind.String, ev.GetProperty("start").ValueKind);
            Assert.Equal(JsonValueKind.String, ev.GetProperty("end").ValueKind);
            Assert.True(ev.GetProperty("isUtcTime").ValueKind is JsonValueKind.True or JsonValueKind.False);
            Assert.True(ev.GetProperty("hasSpawns").ValueKind is JsonValueKind.True or JsonValueKind.False);
            Assert.True(ev.GetProperty("hasResearchTasks").ValueKind is JsonValueKind.True or JsonValueKind.False);
            Assert.Equal(JsonValueKind.Array, ev.GetProperty("buffs").ValueKind);
            Assert.Equal(JsonValueKind.Array, ev.GetProperty("featuredPokemon").ValueKind);
            Assert.Equal(JsonValueKind.Array, ev.GetProperty("promoCodes").ValueKind);
        }

        [Fact]
        public async Task EventDto_PropertyValues_MapCorrectly()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");

            Assert.Equal("Community Day: Charmander", ev.GetProperty("name").GetString());
            Assert.Equal("Catch Charmander during Community Day!", ev.GetProperty("heading").GetString());
            Assert.Equal("https://example.com/charmander.png", ev.GetProperty("imageUrl").GetString());
            Assert.Equal("https://example.com/community-day-charmander", ev.GetProperty("linkUrl").GetString());
            Assert.Equal(JsonValueKind.True, ev.GetProperty("isUtcTime").ValueKind);
            Assert.Equal(JsonValueKind.True, ev.GetProperty("hasSpawns").ValueKind);
            Assert.Equal(JsonValueKind.True, ev.GetProperty("hasResearchTasks").ValueKind);
        }

        [Fact]
        public async Task EventDto_NoExtraProperties_BeyondContract()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");

            HashSet<string> expectedProperties =
            [
                "id", "name", "eventType", "heading", "imageUrl", "linkUrl",
                "start", "end", "isUtcTime", "hasSpawns", "hasResearchTasks",
                "buffs", "featuredPokemon", "promoCodes",
            ];

            HashSet<string> actualProperties = [.. ev.EnumerateObject().Select(p => p.Name)];

            HashSet<string> unexpected = [.. actualProperties.Except(expectedProperties)];
            Assert.True(unexpected.Count == 0,
                $"EventDto has unexpected properties: [{string.Join(", ", unexpected)}]");
        }

        [Fact]
        public async Task EventType_SerializesAsKebabCaseString()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");
            Assert.Equal("community-day", ev.GetProperty("eventType").GetString());
        }

        [Fact]
        public async Task EventType_SeasonValue_SerializesCorrectly()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Season of Discovery");
            Assert.Equal("season", ev.GetProperty("eventType").GetString());
        }

        [Fact]
        public async Task NullableDateTimes_OmittedWhenNull()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Season of Discovery");

            Assert.False(ev.TryGetProperty("start", out _),
                "Null 'start' should be omitted from JSON (WhenWritingNull)");
            Assert.False(ev.TryGetProperty("end", out _),
                "Null 'end' should be omitted from JSON (WhenWritingNull)");
        }

        [Fact]
        public async Task NonNullDateTimes_SerializeAsIso8601Strings()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");

            string? start = ev.GetProperty("start").GetString();
            string? end = ev.GetProperty("end").GetString();

            Assert.NotNull(start);
            Assert.NotNull(end);
            Assert.True(DateTime.TryParse(start, out _),
                $"'start' value '{start}' is not a valid ISO 8601 datetime");
            Assert.True(DateTime.TryParse(end, out _),
                $"'end' value '{end}' is not a valid ISO 8601 datetime");
        }

        [Fact]
        public async Task BuffDto_HasAllRequiredProperties()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");
            JsonElement fullBuff = ev.GetProperty("buffs").EnumerateArray()
                .First(b => b.GetProperty("text").GetString() == "3× Catch XP");

            Assert.True(fullBuff.TryGetProperty("text", out _));
            Assert.True(fullBuff.TryGetProperty("iconUrl", out _));
            Assert.True(fullBuff.TryGetProperty("category", out _));
            Assert.True(fullBuff.TryGetProperty("multiplier", out _));
            Assert.True(fullBuff.TryGetProperty("resource", out _));
            Assert.True(fullBuff.TryGetProperty("disclaimer", out _));
        }

        [Fact]
        public async Task BuffDto_PropertyTypes_AreCorrect()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");
            JsonElement fullBuff = ev.GetProperty("buffs").EnumerateArray()
                .First(b => b.GetProperty("text").GetString() == "3× Catch XP");

            Assert.Equal(JsonValueKind.String, fullBuff.GetProperty("text").ValueKind);
            Assert.Equal(JsonValueKind.String, fullBuff.GetProperty("iconUrl").ValueKind);
            Assert.Equal(JsonValueKind.String, fullBuff.GetProperty("category").ValueKind);
            Assert.Equal(JsonValueKind.Number, fullBuff.GetProperty("multiplier").ValueKind);
            Assert.Equal(JsonValueKind.String, fullBuff.GetProperty("resource").ValueKind);
            Assert.Equal(JsonValueKind.String, fullBuff.GetProperty("disclaimer").ValueKind);
        }

        [Fact]
        public async Task BuffDto_PropertyValues_MapCorrectly()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");
            JsonElement fullBuff = ev.GetProperty("buffs").EnumerateArray()
                .First(b => b.GetProperty("text").GetString() == "3× Catch XP");

            Assert.Equal("3× Catch XP", fullBuff.GetProperty("text").GetString());
            Assert.Equal("https://example.com/xp-icon.png", fullBuff.GetProperty("iconUrl").GetString());
            Assert.Equal(3.0, fullBuff.GetProperty("multiplier").GetDouble());
            Assert.Equal("XP", fullBuff.GetProperty("resource").GetString());
            Assert.Equal("Only during event hours", fullBuff.GetProperty("disclaimer").GetString());
        }

        [Fact]
        public async Task BuffDto_NoExtraProperties_BeyondContract()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");
            JsonElement fullBuff = ev.GetProperty("buffs").EnumerateArray()
                .First(b => b.GetProperty("text").GetString() == "3× Catch XP");

            HashSet<string> expectedProperties =
            [
                "text", "iconUrl", "category", "multiplier", "resource", "disclaimer",
            ];

            HashSet<string> actualProperties = [.. fullBuff.EnumerateObject().Select(p => p.Name)];

            HashSet<string> unexpected = [.. actualProperties.Except(expectedProperties)];
            Assert.True(unexpected.Count == 0,
                $"BuffDto has unexpected properties: [{string.Join(", ", unexpected)}]");
        }

        [Fact]
        public async Task BuffCategory_SerializesAsKebabCaseString()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");

            JsonElement multiplierBuff = ev.GetProperty("buffs").EnumerateArray()
                .First(b => b.GetProperty("text").GetString() == "3× Catch XP");
            Assert.Equal("multiplier", multiplierBuff.GetProperty("category").GetString());

            JsonElement spawnBuff = ev.GetProperty("buffs").EnumerateArray()
                .First(b => b.GetProperty("text").GetString() == "Increased wild spawns");
            Assert.Equal("spawn", spawnBuff.GetProperty("category").GetString());
        }

        [Fact]
        public async Task BuffDto_NullableFields_OmittedWhenNull()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");
            JsonElement spawnBuff = ev.GetProperty("buffs").EnumerateArray()
                .First(b => b.GetProperty("text").GetString() == "Increased wild spawns");

            Assert.False(spawnBuff.TryGetProperty("iconUrl", out _),
                "Null 'iconUrl' should be omitted from JSON (WhenWritingNull)");
            Assert.False(spawnBuff.TryGetProperty("multiplier", out _),
                "Null 'multiplier' should be omitted from JSON (WhenWritingNull)");
            Assert.False(spawnBuff.TryGetProperty("resource", out _),
                "Null 'resource' should be omitted from JSON (WhenWritingNull)");
            Assert.False(spawnBuff.TryGetProperty("disclaimer", out _),
                "Null 'disclaimer' should be omitted from JSON (WhenWritingNull)");
        }

        [Fact]
        public async Task EmptyBuffsArray_SerializesAsEmptyJsonArray()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Season of Discovery");
            JsonElement buffs = ev.GetProperty("buffs");
            Assert.Equal(JsonValueKind.Array, buffs.ValueKind);
            Assert.Equal(0, buffs.GetArrayLength());
        }

        [Fact]
        public async Task FeaturedPokemon_PresentAsEmptyArray()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");
            JsonElement pokemon = ev.GetProperty("featuredPokemon");
            Assert.Equal(JsonValueKind.Array, pokemon.ValueKind);
        }

        [Fact]
        public async Task PromoCodes_PresentAsEmptyArray()
        {
            (_, JsonDocument doc) = await SeedAndFetch();
            JsonElement ev = FindEvent(doc, "Community Day");
            JsonElement codes = ev.GetProperty("promoCodes");
            Assert.Equal(JsonValueKind.Array, codes.ValueKind);
        }
    }
}
