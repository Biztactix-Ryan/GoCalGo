using System.Net;
using GoCalGo.Api.Configuration;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using WireMock.RequestBuilders;
using WireMock.ResponseBuilders;
using WireMock.Server;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Tests the ScrapedDuckClient against a real WireMock HTTP server
    /// to validate request construction, response parsing, and error handling.
    /// </summary>
    public class ScrapedDuckClientWireMockTests : IDisposable
    {
        private readonly WireMockServer _server;
        private readonly ScrapedDuckClient _client;

        private static readonly string ValidEventsJson = """
            [
                {
                    "eventID": "evt-cd-march",
                    "name": "Community Day: March 2026",
                    "eventType": "community-day",
                    "heading": "Featuring Bulbasaur",
                    "image": "https://example.com/cd-march.png",
                    "link": "https://pokemongolive.com/events/cd-march-2026",
                    "start": "2026-03-15 11:00",
                    "end": "2026-03-15 17:00",
                    "extraData": {
                        "communityday": {
                            "spawns": [{"name": "Bulbasaur", "image": "https://img.pokemondb.net/bulbasaur.png", "canBeShiny": true}],
                            "bonuses": [{"text": "3x Catch Stardust", "image": "https://example.com/stardust.png"}],
                            "bonusDisclaimers": ["Some bonuses require a ticket"]
                        }
                    }
                },
                {
                    "eventID": "evt-sh-march",
                    "name": "Spotlight Hour",
                    "eventType": "pokemon-spotlight-hour",
                    "heading": "Featuring Pikachu",
                    "image": "https://example.com/sh-march.png",
                    "link": "https://pokemongolive.com/events/sh-march-2026",
                    "start": "2026-03-18T18:00:00Z",
                    "end": "2026-03-18T19:00:00Z",
                    "extraData": {
                        "spotlighthour": {
                            "pokemon": {"name": "Pikachu", "image": "https://img.pokemondb.net/pikachu.png", "canBeShiny": true},
                            "bonus": {"text": "2x Transfer Candy", "image": "https://example.com/candy.png"}
                        }
                    }
                }
            ]
            """;

        public ScrapedDuckClientWireMockTests()
        {
            _server = WireMockServer.Start();

            IOptions<ScrapedDuckSettings> settings = Options.Create(new ScrapedDuckSettings
            {
                BaseUrl = _server.Url!
            });

            HttpClient httpClient = new();
            _client = new ScrapedDuckClient(
                httpClient,
                settings,
                NullLogger<ScrapedDuckClient>.Instance);
        }

        public void Dispose()
        {
            _server.Stop();
            _server.Dispose();
            GC.SuppressFinalize(this);
        }

        [Fact]
        public async Task FetchEventsAsync_ReturnsEvents_WhenServerReturnsValidJson()
        {
            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithHeader("Content-Type", "application/json")
                    .WithBody(ValidEventsJson));

            IReadOnlyList<ParsedEvent> events = await _client.FetchEventsAsync();

            Assert.Equal(2, events.Count);

            ParsedEvent cd = events[0];
            Assert.Equal("evt-cd-march", cd.Id);
            Assert.Equal("Community Day: March 2026", cd.Name);
            Assert.Equal(EventType.CommunityDay, cd.EventType);
            Assert.Equal("Featuring Bulbasaur", cd.Heading);
            Assert.NotNull(cd.Start);
            Assert.NotNull(cd.End);
            Assert.False(cd.IsUtcTime);
            Assert.Single(cd.Buffs);
            Assert.Equal("3x Catch Stardust", cd.Buffs[0].Text);
            Assert.Single(cd.FeaturedPokemon);
            Assert.Equal("Bulbasaur", cd.FeaturedPokemon[0].Name);

            ParsedEvent sh = events[1];
            Assert.Equal("evt-sh-march", sh.Id);
            Assert.Equal(EventType.SpotlightHour, sh.EventType);
            Assert.True(sh.IsUtcTime);
            Assert.Single(sh.Buffs);
            Assert.Equal("2x Transfer Candy", sh.Buffs[0].Text);
            Assert.Single(sh.FeaturedPokemon);
            Assert.Equal("Pikachu", sh.FeaturedPokemon[0].Name);
        }

        [Fact]
        public async Task FetchEventsAsync_ReturnsEmptyList_WhenServerReturnsEmptyArray()
        {
            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithHeader("Content-Type", "application/json")
                    .WithBody("[]"));

            IReadOnlyList<ParsedEvent> events = await _client.FetchEventsAsync();

            Assert.Empty(events);
        }

        [Fact]
        public async Task FetchEventsAsync_RequestsCorrectPath()
        {
            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithHeader("Content-Type", "application/json")
                    .WithBody("[]"));

            await _client.FetchEventsAsync();

            Assert.Single(_server.LogEntries);
            Assert.Equal("/data/events.json", _server.LogEntries[0].RequestMessage.Path);
            Assert.Equal("GET", _server.LogEntries[0].RequestMessage.Method);
        }

        [Theory]
        [InlineData(HttpStatusCode.InternalServerError)]
        [InlineData(HttpStatusCode.ServiceUnavailable)]
        [InlineData(HttpStatusCode.BadGateway)]
        [InlineData(HttpStatusCode.NotFound)]
        [InlineData(HttpStatusCode.Forbidden)]
        public async Task FetchEventsAsync_ThrowsScrapedDuckClientException_OnErrorStatusCodes(HttpStatusCode statusCode)
        {
            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode((int)statusCode)
                    .WithBody("Error"));

            ScrapedDuckClientException ex = await Assert.ThrowsAsync<ScrapedDuckClientException>(
                () => _client.FetchEventsAsync());

            Assert.Contains(((int)statusCode).ToString(System.Globalization.CultureInfo.InvariantCulture), ex.Message);
        }

        [Fact]
        public async Task FetchEventsAsync_ThrowsScrapedDuckClientException_OnMalformedJson()
        {
            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithHeader("Content-Type", "application/json")
                    .WithBody("{not valid json!!!"));

            ScrapedDuckClientException ex = await Assert.ThrowsAsync<ScrapedDuckClientException>(
                () => _client.FetchEventsAsync());

            Assert.Contains("malformed JSON", ex.Message);
        }

        [Fact]
        public async Task FetchEventsAsync_ThrowsScrapedDuckClientException_OnNonArrayJson()
        {
            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithHeader("Content-Type", "application/json")
                    .WithBody("""{"events": []}"""));

            ScrapedDuckClientException ex = await Assert.ThrowsAsync<ScrapedDuckClientException>(
                () => _client.FetchEventsAsync());

            Assert.Contains("Expected JSON array", ex.Message);
        }

        [Fact]
        public async Task FetchEventsAsync_ThrowsScrapedDuckClientException_OnTimeout()
        {
            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithDelay(TimeSpan.FromSeconds(5))
                    .WithBody("[]"));

            // Use a short timeout to trigger the timeout path
            IOptions<ScrapedDuckSettings> settings = Options.Create(new ScrapedDuckSettings
            {
                BaseUrl = _server.Url!
            });

            HttpClient httpClient = new() { Timeout = TimeSpan.FromMilliseconds(100) };
            ScrapedDuckClient timeoutClient = new(
                httpClient,
                settings,
                NullLogger<ScrapedDuckClient>.Instance);

            ScrapedDuckClientException ex = await Assert.ThrowsAsync<ScrapedDuckClientException>(
                () => timeoutClient.FetchEventsAsync());

            Assert.Contains("timed out", ex.Message);
        }

        [Fact]
        public async Task FetchEventsAsync_ParsesEventTypesCorrectly()
        {
            string json = """
                [
                    {"eventID":"e1","name":"GBL Season","eventType":"go-battle-league","heading":"h","image":"i","link":"l","start":null,"end":null,"extraData":{}},
                    {"eventID":"e2","name":"Rocket Takeover","eventType":"go-rocket-takeover","heading":"h","image":"i","link":"l","start":null,"end":null,"extraData":{}},
                    {"eventID":"e3","name":"Research Day","eventType":"research-day","heading":"h","image":"i","link":"l","start":null,"end":null,"extraData":{}},
                    {"eventID":"e4","name":"Go Fest","eventType":"pokemon-go-fest","heading":"h","image":"i","link":"l","start":null,"end":null,"extraData":{}},
                    {"eventID":"e5","name":"Season","eventType":"season","heading":"h","image":"i","link":"l","start":null,"end":null,"extraData":{}},
                    {"eventID":"e6","name":"Unknown","eventType":"brand-new-type","heading":"h","image":"i","link":"l","start":null,"end":null,"extraData":{}}
                ]
                """;

            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithHeader("Content-Type", "application/json")
                    .WithBody(json));

            IReadOnlyList<ParsedEvent> events = await _client.FetchEventsAsync();

            Assert.Equal(6, events.Count);
            Assert.Equal(EventType.GoBattleLeague, events[0].EventType);
            Assert.Equal(EventType.GoRocket, events[1].EventType);
            Assert.Equal(EventType.Research, events[2].EventType);
            Assert.Equal(EventType.PokemonGoFest, events[3].EventType);
            Assert.Equal(EventType.Season, events[4].EventType);
            Assert.Equal(EventType.Other, events[5].EventType);
        }

        [Fact]
        public async Task FetchEventsAsync_ParsesLocalAndUtcTimestamps()
        {
            string json = """
                [
                    {"eventID":"local","name":"Local Event","eventType":"event","heading":"h","image":"i","link":"l","start":"2026-06-01 10:00","end":"2026-06-01 20:00","extraData":{}},
                    {"eventID":"utc","name":"UTC Event","eventType":"event","heading":"h","image":"i","link":"l","start":"2026-06-01T10:00:00Z","end":"2026-06-01T20:00:00Z","extraData":{}}
                ]
                """;

            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithHeader("Content-Type", "application/json")
                    .WithBody(json));

            IReadOnlyList<ParsedEvent> events = await _client.FetchEventsAsync();

            Assert.Equal(2, events.Count);

            // Local time event
            Assert.False(events[0].IsUtcTime);
            Assert.Equal(new DateTime(2026, 6, 1, 10, 0, 0), events[0].Start);

            // UTC time event
            Assert.True(events[1].IsUtcTime);
            Assert.Equal(DateTimeKind.Utc, events[1].Start!.Value.Kind);
        }

        [Fact]
        public async Task FetchEventsAsync_HandlesNullTimestamps()
        {
            string json = """
                [
                    {"eventID":"no-dates","name":"Dateless","eventType":"event","heading":"h","image":"i","link":"l","start":null,"end":null,"extraData":{}}
                ]
                """;

            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithHeader("Content-Type", "application/json")
                    .WithBody(json));

            IReadOnlyList<ParsedEvent> events = await _client.FetchEventsAsync();

            Assert.Single(events);
            Assert.Null(events[0].Start);
            Assert.Null(events[0].End);
            Assert.False(events[0].IsUtcTime);
        }

        [Fact]
        public async Task FetchEventsAsync_SupportsCancellation()
        {
            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithDelay(TimeSpan.FromSeconds(5))
                    .WithBody("[]"));

            using CancellationTokenSource cts = new(TimeSpan.FromMilliseconds(100));

            await Assert.ThrowsAnyAsync<OperationCanceledException>(
                () => _client.FetchEventsAsync(cts.Token));
        }

        [Fact]
        public async Task FetchEventsAsync_ParsesExtraDataFields()
        {
            string json = """
                [
                    {
                        "eventID": "extra-data",
                        "name": "Full Event",
                        "eventType": "community-day",
                        "heading": "h",
                        "image": "i",
                        "link": "l",
                        "start": "2026-03-15 11:00",
                        "end": "2026-03-15 17:00",
                        "extraData": {
                            "generic": {
                                "hasSpawns": true,
                                "hasFieldResearchTasks": true
                            }
                        }
                    }
                ]
                """;

            _server.Given(Request.Create().WithPath("/data/events.json").UsingGet())
                .RespondWith(Response.Create()
                    .WithStatusCode(200)
                    .WithHeader("Content-Type", "application/json")
                    .WithBody(json));

            IReadOnlyList<ParsedEvent> events = await _client.FetchEventsAsync();

            Assert.Single(events);
            Assert.True(events[0].HasSpawns);
            Assert.True(events[0].HasResearchTasks);
        }
    }
}
