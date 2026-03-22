namespace GoCalGo.Contracts.Events
{
    /// <summary>
    /// Maps ScrapedDuck eventType strings to internal EventTypeDto values.
    /// </summary>
    public static class ScrapedDuckEventTypeMap
    {
        private static readonly Dictionary<string, EventTypeDto> Map = new(StringComparer.OrdinalIgnoreCase)
        {
            ["community-day"] = EventTypeDto.CommunityDay,
            ["pokemon-spotlight-hour"] = EventTypeDto.SpotlightHour,
            ["raid-hour"] = EventTypeDto.RaidHour,
            ["bonus-hour"] = EventTypeDto.RaidHour,
            ["raid-day"] = EventTypeDto.RaidDay,
            ["raid-weekend"] = EventTypeDto.RaidDay,
            ["raid-battles"] = EventTypeDto.RaidDay,
            ["elite-raids"] = EventTypeDto.RaidDay,
            ["event"] = EventTypeDto.Event,
            ["live-event"] = EventTypeDto.Event,
            ["update"] = EventTypeDto.Event,
            ["ticketed"] = EventTypeDto.Event,
            ["ticketed-event"] = EventTypeDto.Event,
            ["go-pass"] = EventTypeDto.Event,
            ["pokestop-showcase"] = EventTypeDto.Event,
            ["wild-area"] = EventTypeDto.Event,
            ["city-safari"] = EventTypeDto.Event,
            ["location-specific"] = EventTypeDto.Event,
            ["global-challenge"] = EventTypeDto.Event,
            ["potential-ultra-unlock"] = EventTypeDto.Event,
            ["pokemon-go-tour"] = EventTypeDto.Event,
            ["max-battles"] = EventTypeDto.Event,
            ["max-mondays"] = EventTypeDto.Event,
            ["go-battle-league"] = EventTypeDto.GoBattleLeague,
            ["go-rocket-takeover"] = EventTypeDto.GoRocket,
            ["team-go-rocket"] = EventTypeDto.GoRocket,
            ["giovanni-special-research"] = EventTypeDto.GoRocket,
            ["research"] = EventTypeDto.Research,
            ["timed-research"] = EventTypeDto.Research,
            ["limited-research"] = EventTypeDto.Research,
            ["research-breakthrough"] = EventTypeDto.Research,
            ["special-research"] = EventTypeDto.Research,
            ["research-day"] = EventTypeDto.Research,
            ["pokemon-go-fest"] = EventTypeDto.PokemonGoFest,
            ["safari-zone"] = EventTypeDto.SafariZone,
            ["season"] = EventTypeDto.Season,
        };

        /// <summary>
        /// Resolves a ScrapedDuck eventType string to the internal enum.
        /// Returns <see cref="EventTypeDto.Other"/> for unrecognised types.
        /// </summary>
        public static EventTypeDto Resolve(string scrapedDuckEventType)
        {
            return Map.GetValueOrDefault(scrapedDuckEventType, EventTypeDto.Other);
        }
    }
}
