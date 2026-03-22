using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using GoCalGo.Api.Models;

namespace GoCalGo.Api.Services
{
    /// <summary>
    /// Parses raw ScrapedDuck JSON event elements into normalised model instances.
    /// </summary>
    public static partial class ScrapedDuckEventParser
    {
        private static readonly Dictionary<string, EventType> EventTypeMap = new(StringComparer.OrdinalIgnoreCase)
        {
            ["community-day"] = EventType.CommunityDay,
            ["pokemon-spotlight-hour"] = EventType.SpotlightHour,
            ["raid-hour"] = EventType.RaidHour,
            ["bonus-hour"] = EventType.RaidHour,
            ["raid-day"] = EventType.RaidDay,
            ["raid-weekend"] = EventType.RaidDay,
            ["raid-battles"] = EventType.RaidDay,
            ["elite-raids"] = EventType.RaidDay,
            ["event"] = EventType.Event,
            ["live-event"] = EventType.Event,
            ["update"] = EventType.Event,
            ["ticketed"] = EventType.Event,
            ["ticketed-event"] = EventType.Event,
            ["go-pass"] = EventType.Event,
            ["pokestop-showcase"] = EventType.Event,
            ["wild-area"] = EventType.Event,
            ["city-safari"] = EventType.Event,
            ["location-specific"] = EventType.Event,
            ["global-challenge"] = EventType.Event,
            ["potential-ultra-unlock"] = EventType.Event,
            ["pokemon-go-tour"] = EventType.Event,
            ["max-battles"] = EventType.Event,
            ["max-mondays"] = EventType.Event,
            ["go-battle-league"] = EventType.GoBattleLeague,
            ["go-rocket-takeover"] = EventType.GoRocket,
            ["team-go-rocket"] = EventType.GoRocket,
            ["giovanni-special-research"] = EventType.GoRocket,
            ["research"] = EventType.Research,
            ["timed-research"] = EventType.Research,
            ["limited-research"] = EventType.Research,
            ["research-breakthrough"] = EventType.Research,
            ["special-research"] = EventType.Research,
            ["research-day"] = EventType.Research,
            ["pokemon-go-fest"] = EventType.PokemonGoFest,
            ["safari-zone"] = EventType.SafariZone,
            ["season"] = EventType.Season,
        };

        /// <summary>
        /// Resolves a ScrapedDuck eventType string to the internal enum.
        /// Returns <see cref="EventType.Other"/> for unrecognised types.
        /// </summary>
        public static EventType ResolveEventType(string scrapedDuckEventType)
        {
            return EventTypeMap.GetValueOrDefault(scrapedDuckEventType, EventType.Other);
        }

        /// <summary>
        /// Parses a JSON array of ScrapedDuck events into normalised model instances.
        /// </summary>
        public static IReadOnlyList<ParsedEvent> ParseAll(JsonElement eventsArray)
        {
            List<ParsedEvent> results = new(eventsArray.GetArrayLength());
            foreach (JsonElement element in eventsArray.EnumerateArray())
            {
                results.Add(Parse(element));
            }
            return results;
        }

        /// <summary>
        /// Parses a single ScrapedDuck event JSON element into a normalised model.
        /// </summary>
        public static ParsedEvent Parse(JsonElement element)
        {
            string id = element.GetProperty("eventID").GetString()!;
            string name = element.GetProperty("name").GetString()!;
            string rawEventType = element.GetProperty("eventType").GetString()!;
            string heading = element.GetProperty("heading").GetString()!;
            string imageUrl = element.GetProperty("image").GetString()!;
            string linkUrl = element.GetProperty("link").GetString()!;

            EventType eventType = ResolveEventType(rawEventType);

            (DateTime? start, bool startIsUtc) = ParseTimestamp(element, "start");
            (DateTime? end, bool endIsUtc) = ParseTimestamp(element, "end");
            bool isUtcTime = startIsUtc || endIsUtc;

            JsonElement extraData = element.TryGetProperty("extraData", out JsonElement ed) ? ed : default;

            bool hasSpawns = false;
            bool hasResearchTasks = false;
            if (extraData.ValueKind == JsonValueKind.Object &&
                extraData.TryGetProperty("generic", out JsonElement generic))
            {
                hasSpawns = generic.TryGetProperty("hasSpawns", out JsonElement hs) && hs.GetBoolean();
                hasResearchTasks = generic.TryGetProperty("hasFieldResearchTasks", out JsonElement hfr) && hfr.GetBoolean();
            }

            List<ParsedBuff> buffs = ExtractBuffs(extraData);
            List<ParsedPokemon> pokemon = ExtractPokemon(extraData);
            List<string> promoCodes = ExtractPromoCodes(extraData);

            return new ParsedEvent
            {
                Id = id,
                Name = name,
                EventType = eventType,
                Heading = heading,
                ImageUrl = imageUrl,
                LinkUrl = linkUrl,
                Start = start,
                End = end,
                IsUtcTime = isUtcTime,
                HasSpawns = hasSpawns,
                HasResearchTasks = hasResearchTasks,
                Buffs = buffs,
                FeaturedPokemon = pokemon,
                PromoCodes = promoCodes,
            };
        }

        private static (DateTime? Timestamp, bool IsUtc) ParseTimestamp(JsonElement element, string propertyName)
        {
            if (!element.TryGetProperty(propertyName, out JsonElement prop) ||
                prop.ValueKind == JsonValueKind.Null)
            {
                return (null, false);
            }

            string raw = prop.GetString()!;
            if (string.IsNullOrWhiteSpace(raw))
            {
                return (null, false);
            }

            bool isUtc = raw.EndsWith('Z');

            if (isUtc)
            {
                // Parse as UTC and preserve DateTimeKind.Utc so serialization includes 'Z'
                if (DateTime.TryParse(raw, CultureInfo.InvariantCulture,
                    DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal, out DateTime utcDt))
                {
                    return (utcDt, true);
                }
            }
            else
            {
                // Parse as Unspecified — represents wall-clock local time (same everywhere)
                if (DateTime.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.None, out DateTime localDt))
                {
                    return (localDt, false);
                }
            }

            return (null, false);
        }

        private static List<ParsedBuff> ExtractBuffs(JsonElement extraData)
        {
            List<ParsedBuff> buffs = [];

            if (extraData.ValueKind != JsonValueKind.Object)
            {
                return buffs;
            }

            // Community Day bonuses
            if (extraData.TryGetProperty("communityday", out JsonElement cd))
            {
                string? disclaimer = null;
                if (cd.TryGetProperty("bonusDisclaimers", out JsonElement disclaimers) &&
                    disclaimers.ValueKind == JsonValueKind.Array &&
                    disclaimers.GetArrayLength() > 0)
                {
                    disclaimer = disclaimers[0].GetString();
                }

                if (cd.TryGetProperty("bonuses", out JsonElement bonuses) &&
                    bonuses.ValueKind == JsonValueKind.Array)
                {
                    foreach (JsonElement bonus in bonuses.EnumerateArray())
                    {
                        string text = bonus.GetProperty("text").GetString()!;
                        string? iconUrl = bonus.TryGetProperty("image", out JsonElement img) ? img.GetString() : null;
                        bool hasAsterisk = text.EndsWith('*');

                        buffs.Add(ParseBuffFromText(text.TrimEnd('*'), iconUrl, hasAsterisk ? disclaimer : null));
                    }
                }
            }

            // Spotlight Hour bonus — handle both "spotlight" and "spotlighthour" keys
            if (extraData.TryGetProperty("spotlighthour", out JsonElement sh))
            {
                if (sh.TryGetProperty("bonus", out JsonElement bonus))
                {
                    if (bonus.ValueKind == JsonValueKind.Object)
                    {
                        string text = bonus.GetProperty("text").GetString()!;
                        string? iconUrl = bonus.TryGetProperty("image", out JsonElement img) ? img.GetString() : null;
                        buffs.Add(ParseBuffFromText(text, iconUrl, null));
                    }
                    else if (bonus.ValueKind == JsonValueKind.String)
                    {
                        buffs.Add(ParseBuffFromText(bonus.GetString()!, null, null));
                    }
                }
            }
            else if (extraData.TryGetProperty("spotlight", out JsonElement sp))
            {
                if (sp.TryGetProperty("bonus", out JsonElement bonus))
                {
                    if (bonus.ValueKind == JsonValueKind.String)
                    {
                        buffs.Add(ParseBuffFromText(bonus.GetString()!, null, null));
                    }
                    else if (bonus.ValueKind == JsonValueKind.Object)
                    {
                        string text = bonus.GetProperty("text").GetString()!;
                        string? iconUrl = bonus.TryGetProperty("image", out JsonElement img) ? img.GetString() : null;
                        buffs.Add(ParseBuffFromText(text, iconUrl, null));
                    }
                }
            }

            return buffs;
        }

        internal static ParsedBuff ParseBuffFromText(string text, string? iconUrl, string? disclaimer)
        {
            // Normalize unicode multiplier symbol
            string normalized = text.Replace("\u00d7", "x").Replace("\u00D7", "x");

            // Pattern: "Nx <resource>" (e.g. "3x Catch Stardust", "2x Catch Candy")
            Match multiplierMatch = MultiplierPattern().Match(normalized);
            if (multiplierMatch.Success)
            {
                double multiplier = double.Parse(multiplierMatch.Groups[1].Value, CultureInfo.InvariantCulture);
                string resource = multiplierMatch.Groups[2].Value.Trim();

                // "2x Chance to receive..." is probability, not multiplier
                BuffCategory category = resource.StartsWith("Chance", StringComparison.OrdinalIgnoreCase)
                    ? BuffCategory.Probability
                    : BuffCategory.Multiplier;

                return new ParsedBuff
                {
                    Text = text,
                    IconUrl = iconUrl,
                    Category = category,
                    Multiplier = multiplier,
                    Resource = resource,
                    Disclaimer = disclaimer,
                };
            }

            // Pattern: "N-hour <item>" (e.g. "3-hour Incense")
            Match durationMatch = DurationPattern().Match(normalized);
            if (durationMatch.Success)
            {
                double hours = double.Parse(durationMatch.Groups[1].Value, CultureInfo.InvariantCulture);
                string resource = durationMatch.Groups[2].Value.Trim();
                return new ParsedBuff
                {
                    Text = text,
                    IconUrl = iconUrl,
                    Category = BuffCategory.Duration,
                    Multiplier = hours,
                    Resource = resource,
                    Disclaimer = disclaimer,
                };
            }

            // Spawn-related keywords
            if (normalized.Contains("Spawn", StringComparison.OrdinalIgnoreCase))
            {
                return new ParsedBuff
                {
                    Text = text,
                    IconUrl = iconUrl,
                    Category = BuffCategory.Spawn,
                    Disclaimer = disclaimer,
                };
            }

            // Trade-related keywords
            if (normalized.Contains("Trade", StringComparison.OrdinalIgnoreCase) ||
                (normalized.Contains("Stardust", StringComparison.OrdinalIgnoreCase) &&
                 normalized.Contains("less", StringComparison.OrdinalIgnoreCase)))
            {
                return new ParsedBuff
                {
                    Text = text,
                    IconUrl = iconUrl,
                    Category = BuffCategory.Trade,
                    Disclaimer = disclaimer,
                };
            }

            // Default: other
            return new ParsedBuff
            {
                Text = text,
                IconUrl = iconUrl,
                Category = BuffCategory.Other,
                Disclaimer = disclaimer,
            };
        }

        private static List<ParsedPokemon> ExtractPokemon(JsonElement extraData)
        {
            List<ParsedPokemon> pokemon = [];

            if (extraData.ValueKind != JsonValueKind.Object)
            {
                return pokemon;
            }

            // Community Day spawns and shinies
            if (extraData.TryGetProperty("communityday", out JsonElement cd))
            {
                AddPokemonFromArray(cd, "spawns", PokemonRole.Spawn, pokemon);
                AddPokemonFromArray(cd, "shinies", PokemonRole.Shiny, pokemon);
            }

            // Spotlight Hour pokemon — handle both key formats
            if (extraData.TryGetProperty("spotlighthour", out JsonElement sh))
            {
                if (sh.TryGetProperty("pokemon", out JsonElement p) && p.ValueKind == JsonValueKind.Object)
                {
                    pokemon.Add(ParsePokemonElement(p, PokemonRole.Spotlight));
                }
            }
            else if (extraData.TryGetProperty("spotlight", out JsonElement sp))
            {
                if (sp.TryGetProperty("name", out _))
                {
                    pokemon.Add(ParsePokemonElement(sp, PokemonRole.Spotlight));
                }
            }

            // Raid bosses
            if (extraData.TryGetProperty("raidbattles", out JsonElement rb))
            {
                AddPokemonFromArray(rb, "bosses", PokemonRole.RaidBoss, pokemon);
            }

            // Research breakthrough — handle both key formats
            if (extraData.TryGetProperty("researchbreakthrough", out JsonElement rrb))
            {
                if (rrb.TryGetProperty("pokemon", out JsonElement p) && p.ValueKind == JsonValueKind.Object)
                {
                    pokemon.Add(ParsePokemonElement(p, PokemonRole.ResearchBreakthrough));
                }
            }
            else if (extraData.TryGetProperty("breakthrough", out JsonElement bt))
            {
                if (bt.TryGetProperty("name", out _))
                {
                    pokemon.Add(ParsePokemonElement(bt, PokemonRole.ResearchBreakthrough));
                }
            }

            return pokemon;
        }

        private static void AddPokemonFromArray(JsonElement parent, string propertyName, PokemonRole role, List<ParsedPokemon> results)
        {
            if (parent.TryGetProperty(propertyName, out JsonElement array) && array.ValueKind == JsonValueKind.Array)
            {
                foreach (JsonElement p in array.EnumerateArray())
                {
                    results.Add(ParsePokemonElement(p, role));
                }
            }
        }

        private static ParsedPokemon ParsePokemonElement(JsonElement element, PokemonRole role)
        {
            return new ParsedPokemon
            {
                Name = element.GetProperty("name").GetString()!,
                ImageUrl = element.GetProperty("image").GetString()!,
                CanBeShiny = element.TryGetProperty("canBeShiny", out JsonElement cs) && cs.GetBoolean(),
                Role = role,
            };
        }

        private static List<string> ExtractPromoCodes(JsonElement extraData)
        {
            if (extraData.ValueKind != JsonValueKind.Object ||
                !extraData.TryGetProperty("promocodes", out JsonElement codes) ||
                codes.ValueKind != JsonValueKind.Array)
            {
                return [];
            }

            List<string> result = new(codes.GetArrayLength());
            foreach (JsonElement code in codes.EnumerateArray())
            {
                string? value = code.GetString();
                if (!string.IsNullOrEmpty(value))
                {
                    result.Add(value);
                }
            }
            return result;
        }

        [GeneratedRegex(@"^(\d+(?:\.\d+)?)x\s+(.+)$", RegexOptions.IgnoreCase)]
        private static partial Regex MultiplierPattern();

        [GeneratedRegex(@"^(\d+(?:\.\d+)?)-hour\s+(.+)$", RegexOptions.IgnoreCase)]
        private static partial Regex DurationPattern();
    }

    /// <summary>
    /// Intermediate parsed event before database persistence.
    /// </summary>
    public sealed class ParsedEvent
    {
        public required string Id { get; init; }
        public required string Name { get; init; }
        public required EventType EventType { get; init; }
        public required string Heading { get; init; }
        public required string ImageUrl { get; init; }
        public required string LinkUrl { get; init; }
        public DateTime? Start { get; init; }
        public DateTime? End { get; init; }
        public required bool IsUtcTime { get; init; }
        public required bool HasSpawns { get; init; }
        public required bool HasResearchTasks { get; init; }
        public required IReadOnlyList<ParsedBuff> Buffs { get; init; }
        public required IReadOnlyList<ParsedPokemon> FeaturedPokemon { get; init; }
        public required IReadOnlyList<string> PromoCodes { get; init; }
    }

    /// <summary>
    /// Parsed buff with category and optional extracted multiplier/resource.
    /// </summary>
    public sealed class ParsedBuff
    {
        public required string Text { get; init; }
        public string? IconUrl { get; init; }
        public required BuffCategory Category { get; init; }
        public double? Multiplier { get; init; }
        public string? Resource { get; init; }
        public string? Disclaimer { get; init; }
    }

    /// <summary>
    /// Parsed featured Pokemon with role context.
    /// </summary>
    public sealed class ParsedPokemon
    {
        public required string Name { get; init; }
        public required string ImageUrl { get; init; }
        public required bool CanBeShiny { get; init; }
        public required PokemonRole Role { get; init; }
    }

    /// <summary>
    /// Describes a Pokemon's role within an event context.
    /// </summary>
    public enum PokemonRole
    {
        Spawn,
        Shiny,
        Spotlight,
        RaidBoss,
        ResearchReward,
        ResearchBreakthrough,
    }
}
