using System.Text.Json;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;

namespace GoCalGo.Api.Tests.Services
{
    public class ScrapedDuckEventParserTests
    {
        #region Basic field mapping

        [Fact]
        public void Parse_MapsBasicFields()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "april-communityday2026",
                    "name": "Tinkatink Community Day",
                    "eventType": "community-day",
                    "heading": "Community Day",
                    "image": "https://cdn.leekduck.com/cd.jpg",
                    "link": "https://leekduck.com/events/april-communityday2026/",
                    "start": "2026-04-11T14:00:00.000",
                    "end": "2026-04-11T17:00:00.000",
                    "extraData": { "generic": { "hasSpawns": true, "hasFieldResearchTasks": true } }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal("april-communityday2026", dto.Id);
            Assert.Equal("Tinkatink Community Day", dto.Name);
            Assert.Equal("Community Day", dto.Heading);
            Assert.Equal("https://cdn.leekduck.com/cd.jpg", dto.ImageUrl);
            Assert.Equal("https://leekduck.com/events/april-communityday2026/", dto.LinkUrl);
            Assert.True(dto.HasSpawns);
            Assert.True(dto.HasResearchTasks);
        }

        #endregion

        #region Event type normalisation

        [Theory]
        [InlineData("community-day", EventType.CommunityDay)]
        [InlineData("pokemon-spotlight-hour", EventType.SpotlightHour)]
        [InlineData("raid-hour", EventType.RaidHour)]
        [InlineData("bonus-hour", EventType.RaidHour)]
        [InlineData("raid-day", EventType.RaidDay)]
        [InlineData("raid-weekend", EventType.RaidDay)]
        [InlineData("event", EventType.Event)]
        [InlineData("ticketed-event", EventType.Event)]
        [InlineData("go-battle-league", EventType.GoBattleLeague)]
        [InlineData("go-rocket-takeover", EventType.GoRocket)]
        [InlineData("research", EventType.Research)]
        [InlineData("timed-research", EventType.Research)]
        [InlineData("pokemon-go-fest", EventType.PokemonGoFest)]
        [InlineData("safari-zone", EventType.SafariZone)]
        [InlineData("season", EventType.Season)]
        public void Parse_NormalisesEventType(string scrapedDuckType, EventType expected)
        {
            JsonElement element = MakeMinimalEvent(eventType: scrapedDuckType);
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);
            Assert.Equal(expected, dto.EventType);
        }

        [Fact]
        public void Parse_UnknownEventType_MapsToOther()
        {
            JsonElement element = MakeMinimalEvent(eventType: "totally-new-type");
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);
            Assert.Equal(EventType.Other, dto.EventType);
        }

        [Fact]
        public void ResolveEventType_IsCaseInsensitive()
        {
            Assert.Equal(EventType.CommunityDay, ScrapedDuckEventParser.ResolveEventType("Community-Day"));
            Assert.Equal(EventType.CommunityDay, ScrapedDuckEventParser.ResolveEventType("COMMUNITY-DAY"));
        }

        #endregion

        #region Timestamp parsing

        [Fact]
        public void Parse_LocalTimestamp_SetsIsUtcTimeFalse()
        {
            JsonElement element = MakeMinimalEvent(start: "2026-04-11T14:00:00.000", end: "2026-04-11T17:00:00.000");
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(new DateTime(2026, 4, 11, 14, 0, 0), dto.Start);
            Assert.Equal(new DateTime(2026, 4, 11, 17, 0, 0), dto.End);
            Assert.False(dto.IsUtcTime);
        }

        [Fact]
        public void Parse_UtcTimestamp_WithZSuffix_SetsIsUtcTimeTrue()
        {
            JsonElement element = MakeMinimalEvent(start: "2026-03-17T20:00:00.000Z", end: "2026-06-01T20:00:00.000Z");
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(new DateTime(2026, 3, 17, 20, 0, 0), dto.Start);
            Assert.Equal(new DateTime(2026, 6, 1, 20, 0, 0), dto.End);
            Assert.True(dto.IsUtcTime);
        }

        [Fact]
        public void Parse_NullTimestamps_AreHandled()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "evt-1",
                    "name": "Season",
                    "eventType": "season",
                    "heading": "Season",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": null,
                    "end": null,
                    "extraData": { "generic": { "hasSpawns": false, "hasFieldResearchTasks": false } }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Null(dto.Start);
            Assert.Null(dto.End);
            Assert.False(dto.IsUtcTime);
        }

        [Fact]
        public void Parse_TimestampWithoutMilliseconds_Works()
        {
            JsonElement element = MakeMinimalEvent(start: "2026-04-11T14:00:00", end: "2026-04-11T17:00:00");
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(new DateTime(2026, 4, 11, 14, 0, 0), dto.Start);
            Assert.Equal(new DateTime(2026, 4, 11, 17, 0, 0), dto.End);
        }

        [Fact]
        public void Parse_UtcTimestamp_NearDstTransition_PreservesExactTime()
        {
            // UTC timestamp during the spring-forward gap (2 AM EST → 3 AM EDT on March 8, 2026).
            // The parser must store the exact UTC values without local-timezone interference.
            JsonElement element = MakeMinimalEvent(
                start: "2026-03-08T07:00:00.000Z",
                end: "2026-03-08T08:00:00.000Z"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(new DateTime(2026, 3, 8, 7, 0, 0), dto.Start);
            Assert.Equal(new DateTime(2026, 3, 8, 8, 0, 0), dto.End);
            Assert.True(dto.IsUtcTime);
        }

        [Fact]
        public void Parse_LocalTimestamp_OnDstDay_PreservesWallClockTime()
        {
            // Local-time event on spring-forward day — wall-clock must be preserved.
            JsonElement element = MakeMinimalEvent(
                start: "2026-03-08T14:00:00.000",
                end: "2026-03-08T17:00:00.000"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(14, dto.Start!.Value.Hour);
            Assert.Equal(17, dto.End!.Value.Hour);
            Assert.Equal(8, dto.Start.Value.Day);
            Assert.False(dto.IsUtcTime);
        }

        [Fact]
        public void Parse_LocalTimestamp_CrossingMidnight_PreservesBothDays()
        {
            // Event from late evening to early morning next day.
            JsonElement element = MakeMinimalEvent(
                start: "2026-03-21T22:00:00.000",
                end: "2026-03-22T02:00:00.000"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(21, dto.Start!.Value.Day);
            Assert.Equal(22, dto.Start.Value.Hour);
            Assert.Equal(22, dto.End!.Value.Day);
            Assert.Equal(2, dto.End.Value.Hour);
        }

        [Fact]
        public void Parse_LocalTimestamp_AtExactMidnight_PreservesHourZero()
        {
            // Midnight boundary — hour 0 on the correct day.
            JsonElement element = MakeMinimalEvent(
                start: "2026-04-01T00:00:00.000",
                end: "2026-04-01T08:00:00.000"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(0, dto.Start!.Value.Hour);
            Assert.Equal(1, dto.Start.Value.Day);
            Assert.Equal(4, dto.Start.Value.Month);
        }

        [Fact]
        public void Parse_UtcTimestamp_CrossingYearBoundary_PreservesBothYears()
        {
            // GBL season spanning year boundary.
            JsonElement element = MakeMinimalEvent(
                start: "2026-12-31T23:00:00.000Z",
                end: "2027-01-01T01:00:00.000Z"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(2026, dto.Start!.Value.Year);
            Assert.Equal(12, dto.Start.Value.Month);
            Assert.Equal(31, dto.Start.Value.Day);
            Assert.Equal(2027, dto.End!.Value.Year);
            Assert.Equal(1, dto.End.Value.Month);
            Assert.Equal(1, dto.End.Value.Day);
            Assert.True(dto.IsUtcTime);
        }

        [Fact]
        public void Parse_LocalTimestamp_LeapYearFeb29_ParsedCorrectly()
        {
            // Feb 29 in a leap year (2028) must parse without error.
            JsonElement element = MakeMinimalEvent(
                start: "2028-02-29T14:00:00.000",
                end: "2028-02-29T17:00:00.000"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(2028, dto.Start!.Value.Year);
            Assert.Equal(2, dto.Start.Value.Month);
            Assert.Equal(29, dto.Start.Value.Day);
            Assert.Equal(14, dto.Start.Value.Hour);
        }

        #endregion

        #region Community Day buff extraction

        [Fact]
        public void Parse_CommunityDay_ExtractsMultiplierBuffs()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "cd-1",
                    "name": "CD",
                    "eventType": "community-day",
                    "heading": "Community Day",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-04-11T14:00:00.000",
                    "end": "2026-04-11T17:00:00.000",
                    "extraData": {
                        "communityday": {
                            "bonuses": [
                                { "text": "3x Catch Stardust", "image": "stardust3x.png" },
                                { "text": "2x Catch Candy", "image": "candy.png" }
                            ],
                            "spawns": [],
                            "shinies": [],
                            "bonusDisclaimers": []
                        },
                        "generic": { "hasSpawns": true, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(2, dto.Buffs.Count);

            Assert.Equal("3x Catch Stardust", dto.Buffs[0].Text);
            Assert.Equal(BuffCategory.Multiplier, dto.Buffs[0].Category);
            Assert.Equal(3.0, dto.Buffs[0].Multiplier);
            Assert.Equal("Catch Stardust", dto.Buffs[0].Resource);

            Assert.Equal("2x Catch Candy", dto.Buffs[1].Text);
            Assert.Equal(BuffCategory.Multiplier, dto.Buffs[1].Category);
            Assert.Equal(2.0, dto.Buffs[1].Multiplier);
            Assert.Equal("Catch Candy", dto.Buffs[1].Resource);
        }

        [Fact]
        public void Parse_CommunityDay_ExtractsDurationBuffs()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "cd-2",
                    "name": "CD",
                    "eventType": "community-day",
                    "heading": "Community Day",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-04-11T14:00:00.000",
                    "end": "2026-04-11T17:00:00.000",
                    "extraData": {
                        "communityday": {
                            "bonuses": [
                                { "text": "3-hour Incense", "image": "incense.png" }
                            ],
                            "spawns": [],
                            "shinies": [],
                            "bonusDisclaimers": []
                        },
                        "generic": { "hasSpawns": true, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Single(dto.Buffs);
            Assert.Equal(BuffCategory.Duration, dto.Buffs[0].Category);
            Assert.Equal(3.0, dto.Buffs[0].Multiplier);
            Assert.Equal("Incense", dto.Buffs[0].Resource);
        }

        [Fact]
        public void Parse_CommunityDay_ExtractsSpawnBuffs()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "cd-3",
                    "name": "CD",
                    "eventType": "community-day",
                    "heading": "Community Day",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-04-11T14:00:00.000",
                    "end": "2026-04-11T17:00:00.000",
                    "extraData": {
                        "communityday": {
                            "bonuses": [
                                { "text": "Increased Spawns", "image": "wildgrass.png" }
                            ],
                            "spawns": [],
                            "shinies": [],
                            "bonusDisclaimers": []
                        },
                        "generic": { "hasSpawns": true, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Single(dto.Buffs);
            Assert.Equal(BuffCategory.Spawn, dto.Buffs[0].Category);
        }

        [Fact]
        public void Parse_CommunityDay_ExtractsProbabilityBuffs()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "cd-4",
                    "name": "CD",
                    "eventType": "community-day",
                    "heading": "Community Day",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-04-11T14:00:00.000",
                    "end": "2026-04-11T17:00:00.000",
                    "extraData": {
                        "communityday": {
                            "bonuses": [
                                { "text": "2x Chance to receive Candy XL from catching Pokemon", "image": "candyxl.png" }
                            ],
                            "spawns": [],
                            "shinies": [],
                            "bonusDisclaimers": []
                        },
                        "generic": { "hasSpawns": true, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Single(dto.Buffs);
            Assert.Equal(BuffCategory.Probability, dto.Buffs[0].Category);
            Assert.Equal(2.0, dto.Buffs[0].Multiplier);
        }

        [Fact]
        public void Parse_CommunityDay_AttachesDisclaimerToAsteriskedBuffs()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "cd-5",
                    "name": "CD",
                    "eventType": "community-day",
                    "heading": "Community Day",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-04-11T14:00:00.000",
                    "end": "2026-04-11T17:00:00.000",
                    "extraData": {
                        "communityday": {
                            "bonuses": [
                                { "text": "3x Catch Stardust", "image": "stardust3x.png" },
                                { "text": "Trades made will require 50% less Stardust*", "image": "trade.png" }
                            ],
                            "spawns": [],
                            "shinies": [],
                            "bonusDisclaimers": ["* Extended bonus window available until 10 PM"]
                        },
                        "generic": { "hasSpawns": true, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(2, dto.Buffs.Count);
            Assert.Null(dto.Buffs[0].Disclaimer);
            Assert.Equal("* Extended bonus window available until 10 PM", dto.Buffs[1].Disclaimer);
        }

        [Fact]
        public void Parse_CommunityDay_UnicodeMultiplierSymbolNormalised()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "cd-6",
                    "name": "CD",
                    "eventType": "community-day",
                    "heading": "Community Day",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-04-11T14:00:00.000",
                    "end": "2026-04-11T17:00:00.000",
                    "extraData": {
                        "communityday": {
                            "bonuses": [
                                { "text": "2\u00d7 Transfer Candy", "image": "candy.png" }
                            ],
                            "spawns": [],
                            "shinies": [],
                            "bonusDisclaimers": []
                        },
                        "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Single(dto.Buffs);
            Assert.Equal(BuffCategory.Multiplier, dto.Buffs[0].Category);
            Assert.Equal(2.0, dto.Buffs[0].Multiplier);
            Assert.Equal("Transfer Candy", dto.Buffs[0].Resource);
        }

        #endregion

        #region Spotlight Hour buff extraction

        [Fact]
        public void Parse_SpotlightHour_ObjectBonus_Extracted()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "sh-1",
                    "name": "Spotlight Hour",
                    "eventType": "pokemon-spotlight-hour",
                    "heading": "Spotlight",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-03-17T18:00:00.000",
                    "end": "2026-03-17T19:00:00.000",
                    "extraData": {
                        "spotlighthour": {
                            "pokemon": { "name": "Psyduck", "canBeShiny": true, "image": "psyduck.png" },
                            "bonus": { "text": "2x Transfer Candy", "image": "candy.png" }
                        },
                        "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Single(dto.Buffs);
            Assert.Equal("2x Transfer Candy", dto.Buffs[0].Text);
            Assert.Equal(BuffCategory.Multiplier, dto.Buffs[0].Category);
            Assert.Equal(2.0, dto.Buffs[0].Multiplier);
        }

        [Fact]
        public void Parse_SpotlightHour_WikiFormat_StringBonus_Extracted()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "sh-2",
                    "name": "Spotlight Hour",
                    "eventType": "pokemon-spotlight-hour",
                    "heading": "Spotlight",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-03-17T18:00:00.000",
                    "end": "2026-03-17T19:00:00.000",
                    "extraData": {
                        "spotlight": {
                            "name": "Psyduck",
                            "canBeShiny": true,
                            "image": "psyduck.png",
                            "bonus": "2x Catch Stardust"
                        },
                        "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Single(dto.Buffs);
            Assert.Equal("2x Catch Stardust", dto.Buffs[0].Text);
            Assert.Equal(BuffCategory.Multiplier, dto.Buffs[0].Category);
        }

        #endregion

        #region Pokemon extraction

        [Fact]
        public void Parse_CommunityDay_ExtractsSpawnsAndShinies()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "cd-pk",
                    "name": "Tinkatink Community Day",
                    "eventType": "community-day",
                    "heading": "Community Day",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-04-11T14:00:00.000",
                    "end": "2026-04-11T17:00:00.000",
                    "extraData": {
                        "communityday": {
                            "spawns": [
                                { "name": "Tinkatink", "image": "tinkatink.png" }
                            ],
                            "bonuses": [],
                            "shinies": [
                                { "name": "Tinkatink", "image": "tinkatink_shiny.png" }
                            ],
                            "bonusDisclaimers": []
                        },
                        "generic": { "hasSpawns": true, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(2, dto.FeaturedPokemon.Count);

            Assert.Equal("Tinkatink", dto.FeaturedPokemon[0].Name);
            Assert.Equal(PokemonRole.Spawn, dto.FeaturedPokemon[0].Role);

            Assert.Equal("Tinkatink", dto.FeaturedPokemon[1].Name);
            Assert.Equal(PokemonRole.Shiny, dto.FeaturedPokemon[1].Role);
        }

        [Fact]
        public void Parse_SpotlightHour_ExtractsSpotlightPokemon()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "sh-pk",
                    "name": "Spotlight Hour",
                    "eventType": "pokemon-spotlight-hour",
                    "heading": "Spotlight",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-03-17T18:00:00.000",
                    "end": "2026-03-17T19:00:00.000",
                    "extraData": {
                        "spotlighthour": {
                            "pokemon": { "name": "Psyduck", "canBeShiny": true, "image": "psyduck.png" },
                            "bonus": { "text": "2x Transfer Candy", "image": "candy.png" }
                        },
                        "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Single(dto.FeaturedPokemon);
            Assert.Equal("Psyduck", dto.FeaturedPokemon[0].Name);
            Assert.True(dto.FeaturedPokemon[0].CanBeShiny);
            Assert.Equal(PokemonRole.Spotlight, dto.FeaturedPokemon[0].Role);
        }

        [Fact]
        public void Parse_RaidBattles_ExtractsRaidBosses()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "raid-1",
                    "name": "Raid Battles",
                    "eventType": "raid-battles",
                    "heading": "Raids",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-03-20T10:00:00.000",
                    "end": "2026-03-27T10:00:00.000",
                    "extraData": {
                        "raidbattles": {
                            "bosses": [
                                { "name": "Tapu Koko", "image": "tapu_koko.png", "canBeShiny": true }
                            ],
                            "shinies": []
                        },
                        "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Single(dto.FeaturedPokemon);
            Assert.Equal("Tapu Koko", dto.FeaturedPokemon[0].Name);
            Assert.True(dto.FeaturedPokemon[0].CanBeShiny);
            Assert.Equal(PokemonRole.RaidBoss, dto.FeaturedPokemon[0].Role);
        }

        [Fact]
        public void Parse_ResearchBreakthrough_ExtractsPokemon()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "rb-1",
                    "name": "Research Breakthrough",
                    "eventType": "research-breakthrough",
                    "heading": "Research",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-03-01T13:00:00.000",
                    "end": "2026-04-01T13:00:00.000",
                    "extraData": {
                        "researchbreakthrough": {
                            "pokemon": { "name": "Furfrou", "canBeShiny": true, "image": "furfrou.png" }
                        },
                        "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Single(dto.FeaturedPokemon);
            Assert.Equal("Furfrou", dto.FeaturedPokemon[0].Name);
            Assert.Equal(PokemonRole.ResearchBreakthrough, dto.FeaturedPokemon[0].Role);
        }

        #endregion

        #region Promo codes

        [Fact]
        public void Parse_ExtractsPromoCodes()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "promo-1",
                    "name": "[Promo Code] GO Tour Research",
                    "eventType": "research",
                    "heading": "Research",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-02-19T19:00:00.000",
                    "end": "2026-03-02T00:00:00.000",
                    "extraData": {
                        "promocodes": ["TH4NKY0UF41RYMUCH", "ANOTHER1"],
                        "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(2, dto.PromoCodes.Count);
            Assert.Equal("TH4NKY0UF41RYMUCH", dto.PromoCodes[0]);
            Assert.Equal("ANOTHER1", dto.PromoCodes[1]);
        }

        [Fact]
        public void Parse_NoPromoCodes_ReturnsEmptyList()
        {
            JsonElement element = MakeMinimalEvent();
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);
            Assert.Empty(dto.PromoCodes);
        }

        #endregion

        #region ParseAll

        [Fact]
        public void ParseAll_ParsesMultipleEvents()
        {
            JsonElement array = JsonElement.Parse("""
                [
                    {
                        "eventID": "evt-1",
                        "name": "Event 1",
                        "eventType": "event",
                        "heading": "Event",
                        "image": "img1.png",
                        "link": "http://example.com/1",
                        "start": "2026-03-15T11:00:00.000",
                        "end": "2026-03-15T17:00:00.000",
                        "extraData": { "generic": { "hasSpawns": false, "hasFieldResearchTasks": false } }
                    },
                    {
                        "eventID": "evt-2",
                        "name": "Event 2",
                        "eventType": "community-day",
                        "heading": "CD",
                        "image": "img2.png",
                        "link": "http://example.com/2",
                        "start": "2026-04-11T14:00:00.000",
                        "end": "2026-04-11T17:00:00.000",
                        "extraData": { "generic": { "hasSpawns": true, "hasFieldResearchTasks": false } }
                    }
                ]
                """);

            IReadOnlyList<ParsedEvent> dtos = ScrapedDuckEventParser.ParseAll(array);

            Assert.Equal(2, dtos.Count);
            Assert.Equal("evt-1", dtos[0].Id);
            Assert.Equal(EventType.Event, dtos[0].EventType);
            Assert.Equal("evt-2", dtos[1].Id);
            Assert.Equal(EventType.CommunityDay, dtos[1].EventType);
        }

        #endregion

        #region Generic flags

        [Fact]
        public void Parse_MissingExtraData_DefaultsFlagsToFalse()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "evt-noextra",
                    "name": "No Extra",
                    "eventType": "event",
                    "heading": "Event",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-03-15T11:00:00.000",
                    "end": "2026-03-15T17:00:00.000"
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.False(dto.HasSpawns);
            Assert.False(dto.HasResearchTasks);
            Assert.Empty(dto.Buffs);
            Assert.Empty(dto.FeaturedPokemon);
            Assert.Empty(dto.PromoCodes);
        }

        [Fact]
        public void Parse_EmptyExtraData_DefaultsFlagsToFalse()
        {
            JsonElement element = MakeMinimalEvent();
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.False(dto.HasSpawns);
            Assert.False(dto.HasResearchTasks);
        }

        #endregion

        #region Trade buff category

        [Fact]
        public void Parse_TradeBonus_CategorisedAsTrade()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "cd-trade",
                    "name": "CD",
                    "eventType": "community-day",
                    "heading": "CD",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-04-11T14:00:00.000",
                    "end": "2026-04-11T17:00:00.000",
                    "extraData": {
                        "communityday": {
                            "bonuses": [
                                { "text": "One additional Special Trade can be made", "image": "trade.png" }
                            ],
                            "spawns": [],
                            "shinies": [],
                            "bonusDisclaimers": []
                        },
                        "generic": { "hasSpawns": false, "hasFieldResearchTasks": false }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Single(dto.Buffs);
            Assert.Equal(BuffCategory.Trade, dto.Buffs[0].Category);
        }

        #endregion

        #region Full Community Day integration

        [Fact]
        public void Parse_FullCommunityDayEvent_NormalisedCorrectly()
        {
            JsonElement element = ParseElement("""
                {
                    "eventID": "april-communityday2026",
                    "name": "Tinkatink Community Day",
                    "eventType": "community-day",
                    "heading": "Community Day",
                    "link": "https://leekduck.com/events/april-communityday2026/",
                    "image": "https://cdn.leekduck.com/cd.jpg",
                    "start": "2026-04-11T14:00:00.000",
                    "end": "2026-04-11T17:00:00.000",
                    "extraData": {
                        "communityday": {
                            "spawns": [
                                { "name": "Tinkatink", "image": "tinkatink.png" }
                            ],
                            "bonuses": [
                                { "text": "Increased Spawns", "image": "wildgrass.png" },
                                { "text": "3x Catch Stardust", "image": "stardust3x.png" },
                                { "text": "3-hour Incense", "image": "incense.png" },
                                { "text": "2x Catch Candy", "image": "candy.png" },
                                { "text": "2x Chance to receive Candy XL from catching Pokemon", "image": "candyxl.png" }
                            ],
                            "bonusDisclaimers": ["* Extended bonus window..."],
                            "shinies": [
                                { "name": "Tinkatink", "image": "tinkatink_shiny.png" }
                            ]
                        },
                        "generic": { "hasSpawns": true, "hasFieldResearchTasks": true }
                    }
                }
                """);

            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal("april-communityday2026", dto.Id);
            Assert.Equal(EventType.CommunityDay, dto.EventType);
            Assert.Equal(new DateTime(2026, 4, 11, 14, 0, 0), dto.Start);
            Assert.Equal(new DateTime(2026, 4, 11, 17, 0, 0), dto.End);
            Assert.False(dto.IsUtcTime);
            Assert.True(dto.HasSpawns);
            Assert.True(dto.HasResearchTasks);

            Assert.Equal(5, dto.Buffs.Count);
            Assert.Equal(BuffCategory.Spawn, dto.Buffs[0].Category);
            Assert.Equal(BuffCategory.Multiplier, dto.Buffs[1].Category);
            Assert.Equal(BuffCategory.Duration, dto.Buffs[2].Category);
            Assert.Equal(BuffCategory.Multiplier, dto.Buffs[3].Category);
            Assert.Equal(BuffCategory.Probability, dto.Buffs[4].Category);

            Assert.Equal(2, dto.FeaturedPokemon.Count);
            Assert.Equal(PokemonRole.Spawn, dto.FeaturedPokemon[0].Role);
            Assert.Equal(PokemonRole.Shiny, dto.FeaturedPokemon[1].Role);

            Assert.Empty(dto.PromoCodes);
        }

        #endregion

        #region Helpers

        private static JsonElement ParseElement(string json)
        {
            return JsonElement.Parse(json);
        }

        private static JsonElement MakeMinimalEvent(
            string eventType = "event",
            string? start = "2026-03-15T11:00:00.000",
            string? end = "2026-03-15T17:00:00.000")
        {
            string startJson = start is null ? "null" : $"\"{start}\"";
            string endJson = end is null ? "null" : $"\"{end}\"";

            return ParseElement($$"""
                {
                    "eventID": "evt-min",
                    "name": "Minimal Event",
                    "eventType": "{{eventType}}",
                    "heading": "Event",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": {{startJson}},
                    "end": {{endJson}},
                    "extraData": { "generic": { "hasSpawns": false, "hasFieldResearchTasks": false } }
                }
                """);
        }

        #endregion
    }
}
