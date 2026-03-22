using System.Text.Json.Serialization;

namespace GoCalGo.Contracts.Events
{
    /// <summary>
    /// Categorises the type of buff/bonus effect.
    /// Serialised as lowercase kebab-case strings.
    /// </summary>
    [JsonConverter(typeof(JsonStringEnumConverter<BuffCategory>))]
    public enum BuffCategory
    {
        [JsonStringEnumMemberName("multiplier")]
        Multiplier,

        [JsonStringEnumMemberName("duration")]
        Duration,

        [JsonStringEnumMemberName("spawn")]
        Spawn,

        [JsonStringEnumMemberName("probability")]
        Probability,

        [JsonStringEnumMemberName("trade")]
        Trade,

        [JsonStringEnumMemberName("weather")]
        Weather,

        [JsonStringEnumMemberName("other")]
        Other,
    }
}
