using System.Text.Json.Serialization;

namespace GoCalGo.Contracts.Events
{
    /// <summary>
    /// API response envelope wrapping event data.
    /// </summary>
    public sealed record EventsResponse
    {
        /// <summary>List of events matching the query.</summary>
        [JsonPropertyName("events")]
        public required IReadOnlyList<EventDto> Events { get; init; }

        /// <summary>Timestamp of the last successful data ingestion from ScrapedDuck.</summary>
        [JsonPropertyName("lastUpdated")]
        public required DateTime LastUpdated { get; init; }

        /// <summary>Whether this response was served from cache.</summary>
        [JsonPropertyName("cacheHit")]
        public required bool CacheHit { get; init; }
    }
}
