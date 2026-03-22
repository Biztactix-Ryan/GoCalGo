namespace GoCalGo.Api.Services
{
    /// <summary>
    /// Defines all Redis cache keys used by the application.
    /// Keys follow the convention "namespace:identifier" to avoid collisions
    /// and make Redis key-space browsing intuitive.
    /// </summary>
    public static class CacheKeys
    {
        /// <summary>
        /// Prefix for all event-related cache entries.
        /// </summary>
        public const string EventsNamespace = "events";

        /// <summary>
        /// Cached JSON array of all calendar events.
        /// Populated by the ingestion job and read by API endpoints.
        /// </summary>
        public const string EventsAll = $"{EventsNamespace}:all";
    }
}
