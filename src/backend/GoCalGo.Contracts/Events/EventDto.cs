using System.Text.Json.Serialization;

namespace GoCalGo.Contracts.Events
{
    /// <summary>
    /// Primary DTO for a Pokemon GO event, with all data pre-shaped for display.
    /// Produced by the backend from ScrapedDuck data; consumed by the Flutter app.
    /// </summary>
    public sealed record EventDto
    {
        /// <summary>Unique identifier for the event (e.g. "community-day-2026-03").</summary>
        [JsonPropertyName("id")]
        public required string Id { get; init; }

        /// <summary>Display name of the event.</summary>
        [JsonPropertyName("name")]
        public required string Name { get; init; }

        /// <summary>Categorised event type (e.g. community-day, spotlight-hour).</summary>
        [JsonPropertyName("eventType")]
        public required EventTypeDto EventType { get; init; }

        /// <summary>Short subtitle or tagline for the event.</summary>
        [JsonPropertyName("heading")]
        public required string Heading { get; init; }

        /// <summary>URL to the event's banner or promotional image.</summary>
        [JsonPropertyName("imageUrl")]
        public required string ImageUrl { get; init; }

        /// <summary>URL to the official event page on pokemongolive.com.</summary>
        [JsonPropertyName("linkUrl")]
        public required string LinkUrl { get; init; }

        /// <summary>Event start time. Null if the start time is unknown.</summary>
        [JsonPropertyName("start")]
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public DateTime? Start { get; init; }

        /// <summary>Event end time. Null if the end time is unknown.</summary>
        [JsonPropertyName("end")]
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public DateTime? End { get; init; }

        /// <summary>Whether start/end times are in UTC (true) or local to the player (false).</summary>
        [JsonPropertyName("isUtcTime")]
        public required bool IsUtcTime { get; init; }

        /// <summary>Whether the event features increased wild Pokemon spawns.</summary>
        [JsonPropertyName("hasSpawns")]
        public required bool HasSpawns { get; init; }

        /// <summary>Whether the event includes special field research tasks.</summary>
        [JsonPropertyName("hasResearchTasks")]
        public required bool HasResearchTasks { get; init; }

        /// <summary>Active buffs and bonuses during this event.</summary>
        [JsonPropertyName("buffs")]
        public required IReadOnlyList<BuffDto> Buffs { get; init; }

        /// <summary>Pokemon highlighted or featured in this event.</summary>
        [JsonPropertyName("featuredPokemon")]
        public required IReadOnlyList<PokemonDto> FeaturedPokemon { get; init; }

        /// <summary>Redeemable promo codes associated with this event.</summary>
        [JsonPropertyName("promoCodes")]
        public required IReadOnlyList<string> PromoCodes { get; init; }
    }
}
