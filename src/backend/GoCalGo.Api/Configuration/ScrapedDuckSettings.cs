namespace GoCalGo.Api.Configuration
{
    public class ScrapedDuckSettings
    {
        public const string SectionName = "ScrapedDuck";

        public string BaseUrl { get; set; } = string.Empty;
        public int ScheduleIntervalMinutes { get; set; } = 15;
        public int CacheExpirationMinutes { get; set; } = 30;

        /// <summary>
        /// Per-key or per-namespace TTL overrides. Keys can be exact cache keys
        /// (e.g., "events:all") or namespace prefixes (e.g., "events").
        /// Values are durations in minutes.
        /// </summary>
        public Dictionary<string, int> CacheTtlOverrideMinutes { get; set; } = [];

        /// <summary>
        /// Resolved TTL overrides as TimeSpan values.
        /// </summary>
        public Dictionary<string, TimeSpan> CacheTtlOverrides =>
            CacheTtlOverrideMinutes.ToDictionary(
                kvp => kvp.Key,
                kvp => TimeSpan.FromMinutes(kvp.Value));
    }
}
