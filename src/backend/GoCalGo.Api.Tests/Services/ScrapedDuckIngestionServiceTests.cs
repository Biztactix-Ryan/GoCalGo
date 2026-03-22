using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using NSubstitute;
using NSubstitute.ExceptionExtensions;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Unit tests for <see cref="ScrapedDuckIngestionService"/> using NSubstitute
    /// to mock external dependencies (IScrapedDuckClient, ICacheService).
    /// </summary>
    public sealed class ScrapedDuckIngestionServiceTests : IDisposable
    {
        private readonly IScrapedDuckClient _client = Substitute.For<IScrapedDuckClient>();
        private readonly ICacheService _cache = Substitute.For<ICacheService>();
        private readonly IngestionStatusTracker _tracker = new();
        private readonly ILogger<ScrapedDuckIngestionService> _logger = Substitute.For<ILogger<ScrapedDuckIngestionService>>();
        private readonly GoCalGoDbContext _db;
        private readonly ScrapedDuckIngestionService _sut;

        public ScrapedDuckIngestionServiceTests()
        {
            DbContextOptions<GoCalGoDbContext> options = new DbContextOptionsBuilder<GoCalGoDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            _db = new GoCalGoDbContext(options);
            _sut = new ScrapedDuckIngestionService(_client, _db, _cache, _tracker, _logger);
        }

        public void Dispose()
        {
            _db.Dispose();
        }

        [Fact]
        public async Task FetchEventsAsync_UpsertsToDatabaseAndRefreshesCache()
        {
            // Arrange
            List<ParsedEvent> events = [CreateParsedEvent("evt-1", "Community Day")];

            _client.FetchEventsAsync(Arg.Any<CancellationToken>())
                .Returns(events);

            // Act
            IReadOnlyList<ParsedEvent> result = await _sut.FetchEventsAsync();

            // Assert
            Assert.Single(result);
            Assert.Equal("evt-1", result[0].Id);

            Event? stored = await _db.Events.FirstOrDefaultAsync(e => e.Id == "evt-1");
            Assert.NotNull(stored);
            Assert.Equal("Community Day", stored.Name);

            await _cache.Received(1).SetAsync(CacheKeys.EventsAll, Arg.Any<string>(), Arg.Any<TimeSpan?>());
        }

        [Fact]
        public async Task FetchEventsAsync_UpdatesStatusTracker_OnSuccess()
        {
            // Arrange
            _client.FetchEventsAsync(Arg.Any<CancellationToken>())
                .Returns(
                [
                    CreateParsedEvent("evt-1", "Raid Hour"),
                    CreateParsedEvent("evt-2", "Spotlight Hour"),
                ]);

            // Act
            await _sut.FetchEventsAsync();

            // Assert
            Assert.True(_tracker.LastFetchSuccess);
            Assert.Equal(2, _tracker.LastFetchEventCount);
            Assert.NotNull(_tracker.LastFetchTime);
        }

        [Fact]
        public async Task FetchEventsAsync_SetsFailureStatus_WhenClientThrows()
        {
            // Arrange
            _client.FetchEventsAsync(Arg.Any<CancellationToken>())
                .ThrowsAsync(new ScrapedDuckClientException("API down"));

            // Act & Assert
            await Assert.ThrowsAsync<ScrapedDuckClientException>(() => _sut.FetchEventsAsync());

            Assert.False(_tracker.LastFetchSuccess);
            Assert.NotNull(_tracker.LastFetchTime);
        }

        [Fact]
        public async Task FetchEventsAsync_DoesNotUpdateCache_WhenClientThrows()
        {
            // Arrange
            _client.FetchEventsAsync(Arg.Any<CancellationToken>())
                .ThrowsAsync(new ScrapedDuckClientException("timeout"));

            // Act
            await Assert.ThrowsAsync<ScrapedDuckClientException>(() => _sut.FetchEventsAsync());

            // Assert — cache should never have been touched
            await _cache.DidNotReceive().SetAsync(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<TimeSpan?>());
        }

        [Fact]
        public async Task FetchEventsAsync_UpsertsExistingEvent()
        {
            // Arrange — seed an existing event
            _db.Events.Add(new Event
            {
                Id = "evt-1",
                Name = "Old Name",
                EventType = EventType.Event,
                Heading = "Old",
                ImageUrl = "https://example.com/old.png",
                LinkUrl = "https://example.com/old",
            });
            await _db.SaveChangesAsync();

            _client.FetchEventsAsync(Arg.Any<CancellationToken>())
                .Returns([CreateParsedEvent("evt-1", "New Name")]);

            // Act
            await _sut.FetchEventsAsync();

            // Assert — name should be updated
            Event? updated = await _db.Events.FirstOrDefaultAsync(e => e.Id == "evt-1");
            Assert.NotNull(updated);
            Assert.Equal("New Name", updated.Name);
        }

        private static ParsedEvent CreateParsedEvent(string id, string name)
        {
            return new ParsedEvent
            {
                Id = id,
                Name = name,
                EventType = EventType.CommunityDay,
                Heading = $"{name} heading",
                ImageUrl = $"https://example.com/{id}.png",
                LinkUrl = $"https://example.com/{id}",
                Start = DateTime.UtcNow,
                End = DateTime.UtcNow.AddHours(3),
                IsUtcTime = true,
                HasSpawns = false,
                HasResearchTasks = false,
                Buffs = [],
                FeaturedPokemon = [],
                PromoCodes = [],
            };
        }
    }
}
