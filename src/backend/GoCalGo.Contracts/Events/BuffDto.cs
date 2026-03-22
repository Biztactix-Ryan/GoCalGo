using System.Text.Json.Serialization;

namespace GoCalGo.Contracts.Events
{
    /// <summary>
    /// Unified representation of a buff or bonus, normalised from ScrapedDuck's various shapes.
    /// </summary>
    public sealed record BuffDto
    {
        /// <summary>Human-readable description of the buff (e.g. "2× Catch XP").</summary>
        [JsonPropertyName("text")]
        public required string Text { get; init; }

        /// <summary>URL to the buff's icon image. Null if no icon is available.</summary>
        [JsonPropertyName("iconUrl")]
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public string? IconUrl { get; init; }

        /// <summary>The type of buff effect (e.g. multiplier, duration, spawn).</summary>
        [JsonPropertyName("category")]
        public required BuffCategory Category { get; init; }

        /// <summary>Multiplier value when category is "multiplier" (e.g. 2.0 for double). Null otherwise.</summary>
        [JsonPropertyName("multiplier")]
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public double? Multiplier { get; init; }

        /// <summary>The game resource affected (e.g. "XP", "Stardust"). Null if not applicable.</summary>
        [JsonPropertyName("resource")]
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public string? Resource { get; init; }

        /// <summary>Disclaimer or fine print about the buff conditions. Null if none.</summary>
        [JsonPropertyName("disclaimer")]
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public string? Disclaimer { get; init; }
    }
}
