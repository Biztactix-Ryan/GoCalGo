using System.Text.Json.Serialization;

namespace GoCalGo.Contracts.Events
{
    /// <summary>
    /// A featured Pokemon within an event context.
    /// </summary>
    public sealed record PokemonDto
    {
        /// <summary>Pokemon species name.</summary>
        [JsonPropertyName("name")]
        public required string Name { get; init; }

        /// <summary>URL to the Pokemon's sprite or artwork.</summary>
        [JsonPropertyName("imageUrl")]
        public required string ImageUrl { get; init; }

        /// <summary>Whether a shiny variant is available during this event.</summary>
        [JsonPropertyName("canBeShiny")]
        public required bool CanBeShiny { get; init; }

        /// <summary>The Pokemon's role in the event (e.g. spawn, raid-boss, spotlight).</summary>
        [JsonPropertyName("role")]
        public required PokemonRole Role { get; init; }
    }
}
