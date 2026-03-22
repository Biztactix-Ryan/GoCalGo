using System.Text.Json.Serialization;

namespace GoCalGo.Contracts.Events
{
    /// <summary>
    /// Describes a Pokemon's role within an event context.
    /// Serialised as lowercase kebab-case strings.
    /// </summary>
    [JsonConverter(typeof(JsonStringEnumConverter<PokemonRole>))]
    public enum PokemonRole
    {
        [JsonStringEnumMemberName("spawn")]
        Spawn,

        [JsonStringEnumMemberName("shiny")]
        Shiny,

        [JsonStringEnumMemberName("spotlight")]
        Spotlight,

        [JsonStringEnumMemberName("raid-boss")]
        RaidBoss,

        [JsonStringEnumMemberName("research-reward")]
        ResearchReward,

        [JsonStringEnumMemberName("research-breakthrough")]
        ResearchBreakthrough,
    }
}
