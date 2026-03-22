using System.Text.Json.Serialization;

namespace GoCalGo.Contracts.Events
{
    /// <summary>
    /// API response envelope for the active-events endpoint.
    /// </summary>
    public sealed record ActiveEventsResponse
    {
        /// <summary>List of currently active events.</summary>
        [JsonPropertyName("events")]
        public required IReadOnlyList<ActiveEventDto> Events { get; init; }

        /// <summary>Timestamp of the last successful data ingestion from ScrapedDuck.</summary>
        [JsonPropertyName("lastUpdated")]
        public required DateTime LastUpdated { get; init; }

        /// <summary>Whether this response was served from cache.</summary>
        [JsonPropertyName("cacheHit")]
        public required bool CacheHit { get; init; }
    }
}
