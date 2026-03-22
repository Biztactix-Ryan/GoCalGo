using System.Text.Json.Serialization;

namespace GoCalGo.Contracts.Events
{
    /// <summary>
    /// Normalised event categories mapping ScrapedDuck's 32 event types into logical groups.
    /// Serialised as lowercase kebab-case strings.
    /// </summary>
    [JsonConverter(typeof(JsonStringEnumConverter<EventTypeDto>))]
    public enum EventTypeDto
    {
        [JsonStringEnumMemberName("community-day")]
        CommunityDay,

        [JsonStringEnumMemberName("spotlight-hour")]
        SpotlightHour,

        [JsonStringEnumMemberName("raid-hour")]
        RaidHour,

        [JsonStringEnumMemberName("raid-day")]
        RaidDay,

        [JsonStringEnumMemberName("event")]
        Event,

        [JsonStringEnumMemberName("go-battle-league")]
        GoBattleLeague,

        [JsonStringEnumMemberName("go-rocket")]
        GoRocket,

        [JsonStringEnumMemberName("research")]
        Research,

        [JsonStringEnumMemberName("pokemon-go-fest")]
        PokemonGoFest,

        [JsonStringEnumMemberName("safari-zone")]
        SafariZone,

        [JsonStringEnumMemberName("season")]
        Season,

        [JsonStringEnumMemberName("other")]
        Other,
    }
}
