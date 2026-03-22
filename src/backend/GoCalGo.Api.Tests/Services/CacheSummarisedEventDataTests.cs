using System.Text.Json;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-4:
    /// "Summarised event data is cached in Redis"
    ///
    /// Uses an in-memory cache test double to validate that normalised/summarised
    /// event data (not raw API responses) is stored in cache via the correct key,
    /// serialized as JSON, and retrievable for API consumers.
    /// </summary>
    public class CacheSummarisedEventDataTests
    {
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

            public bool ContainsKey(string key)
            {
                return _store.ContainsKey(key);
            }
        }

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        };

        private static List<Event> CreateSampleSummarisedEvents()
        {
            return
            [
                new Event
                {
                    Id = "community-day-2026-03",
                    Name = "Community Day: March 2026",
                    EventType = EventType.CommunityDay,
                    Heading = "Community Day",
                    Start = new DateTime(2026, 3, 15, 14, 0, 0),
                    End = new DateTime(2026, 3, 15, 17, 0, 0),
                    IsUtcTime = true,
                    HasSpawns = true,
                    Buffs =
                    [
                        new EventBuff
                        {
                            Text = "3x Catch XP",
                            Category = BuffCategory.Multiplier,
                            Multiplier = 3,
                            Resource = "Catch XP",
                        },
                    ],
                },
                new Event
                {
                    Id = "spotlight-hour-2026-03-17",
                    Name = "Spotlight Hour",
                    EventType = EventType.SpotlightHour,
                    Heading = "Spotlight Hour",
                    Start = new DateTime(2026, 3, 17, 18, 0, 0),
                    End = new DateTime(2026, 3, 17, 19, 0, 0),
                    IsUtcTime = false,
                    HasSpawns = true,
                    Buffs =
                    [
                        new EventBuff
                        {
                            Text = "2x Transfer Candy",
                            Category = BuffCategory.Multiplier,
                            Multiplier = 2,
                            Resource = "Transfer Candy",
                        },
                    ],
                },
            ];
        }

        /// <summary>
        /// Simulates the ingestion-to-cache flow: normalised events are serialized
        /// and stored in cache under the events:all key.
        /// </summary>
        private static async Task CacheSummarisedEvents(ICacheService cache, List<Event> events)
        {
            string json = JsonSerializer.Serialize(events, JsonOptions);
            await cache.SetAsync(CacheKeys.EventsAll, json);
        }

        [Fact]
        public async Task SummarisedEvents_AreCachedUnderEventsAllKey()
        {
            InMemoryCacheService cache = new();
            List<Event> events = CreateSampleSummarisedEvents();

            await CacheSummarisedEvents(cache, events);

            Assert.True(cache.ContainsKey(CacheKeys.EventsAll));
            string? cached = await cache.GetAsync(CacheKeys.EventsAll);
            Assert.NotNull(cached);
        }

        [Fact]
        public async Task CachedData_IsSerialisedJson_NotRawApiResponse()
        {
            InMemoryCacheService cache = new();
            List<Event> events = CreateSampleSummarisedEvents();

            await CacheSummarisedEvents(cache, events);

            string? cached = await cache.GetAsync(CacheKeys.EventsAll);
            Assert.NotNull(cached);

            // Cached data should be a valid JSON array
            List<Event>? deserialized = JsonSerializer.Deserialize<List<Event>>(cached, JsonOptions);
            Assert.NotNull(deserialized);
            Assert.Equal(2, deserialized.Count);
        }

        [Fact]
        public async Task CachedEvents_ContainNormalisedFields()
        {
            InMemoryCacheService cache = new();
            List<Event> events = CreateSampleSummarisedEvents();

            await CacheSummarisedEvents(cache, events);

            string? cached = await cache.GetAsync(CacheKeys.EventsAll);
            List<Event>? deserialized = JsonSerializer.Deserialize<List<Event>>(cached!, JsonOptions);

            Event communityDay = deserialized!.First(e => e.EventType == EventType.CommunityDay);
            Assert.Equal("community-day-2026-03", communityDay.Id);
            Assert.Equal("Community Day: March 2026", communityDay.Name);
            Assert.NotNull(communityDay.Start);
            Assert.NotNull(communityDay.End);
            Assert.True(communityDay.IsUtcTime);
            Assert.True(communityDay.HasSpawns);
        }

        [Fact]
        public async Task CachedEvents_IncludeBuffSummaries()
        {
            InMemoryCacheService cache = new();
            List<Event> events = CreateSampleSummarisedEvents();

            await CacheSummarisedEvents(cache, events);

            string? cached = await cache.GetAsync(CacheKeys.EventsAll);
            List<Event>? deserialized = JsonSerializer.Deserialize<List<Event>>(cached!, JsonOptions);

            Event communityDay = deserialized!.First(e => e.EventType == EventType.CommunityDay);
            Assert.Single(communityDay.Buffs);
            Assert.Equal("3x Catch XP", communityDay.Buffs[0].Text);
            Assert.Equal(BuffCategory.Multiplier, communityDay.Buffs[0].Category);
            Assert.Equal(3, communityDay.Buffs[0].Multiplier);
        }

        [Fact]
        public async Task CachedData_UsesCorrectCacheKey()
        {
            // Verify the cache key constant matches the expected "events:all" value
            Assert.Equal("events:all", CacheKeys.EventsAll);

            InMemoryCacheService cache = new();
            List<Event> events = CreateSampleSummarisedEvents();

            await CacheSummarisedEvents(cache, events);

            // Data should be retrievable via the well-known key
            string? viaCacheKey = await cache.GetAsync(CacheKeys.EventsAll);
            string? viaLiteral = await cache.GetAsync("events:all");
            Assert.Equal(viaCacheKey, viaLiteral);
        }

        [Fact]
        public async Task CachedData_IsRetrievableViaGenericGetAsync()
        {
            ICacheService cache = new InMemoryCacheService();
            List<Event> events = CreateSampleSummarisedEvents();

            // Use SetAsync<T> so serialization matches GetAsync<T> (both use default JsonSerializer)
            await cache.SetAsync(CacheKeys.EventsAll, events);

            List<Event>? retrieved = await cache.GetAsync<List<Event>>(CacheKeys.EventsAll);
            Assert.NotNull(retrieved);
            Assert.Equal(2, retrieved.Count);
            Assert.Contains(retrieved, e => e.Id == "community-day-2026-03");
            Assert.Contains(retrieved, e => e.Id == "spotlight-hour-2026-03-17");
        }

        [Fact]
        public async Task CacheAsidePattern_ReturnsEventsFromCache_WhenPopulated()
        {
            ICacheService cache = new InMemoryCacheService();
            List<Event> events = CreateSampleSummarisedEvents();

            // Pre-populate cache (simulating a prior ingestion run)
            await cache.SetAsync(CacheKeys.EventsAll, events);

            bool dbCalled = false;
            List<Event>? result = await cache.GetOrSetAsync<List<Event>>(
                CacheKeys.EventsAll,
                () =>
                {
                    dbCalled = true;
                    return Task.FromResult<List<Event>?>(events);
                });

            Assert.NotNull(result);
            Assert.Equal(2, result.Count);
            Assert.False(dbCalled, "DB should not be called when summarised data is cached");
        }

        [Fact]
        public async Task MultipleEventTypes_AllCachedTogether()
        {
            ICacheService cache = new InMemoryCacheService();
            List<Event> events =
            [
                new Event { Id = "cd-1", EventType = EventType.CommunityDay },
                new Event { Id = "sh-1", EventType = EventType.SpotlightHour },
                new Event { Id = "rh-1", EventType = EventType.RaidHour },
                new Event { Id = "ev-1", EventType = EventType.Event },
                new Event { Id = "gbl-1", EventType = EventType.GoBattleLeague },
            ];

            await cache.SetAsync(CacheKeys.EventsAll, events);

            List<Event>? retrieved = await cache.GetAsync<List<Event>>(CacheKeys.EventsAll);
            Assert.NotNull(retrieved);
            Assert.Equal(5, retrieved.Count);
            Assert.Equal(5, retrieved.Select(e => e.EventType).Distinct().Count());
        }
    }
}
