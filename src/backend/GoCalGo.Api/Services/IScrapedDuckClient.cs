namespace GoCalGo.Api.Services
{
    /// <summary>
    /// HTTP client for fetching and parsing event data from the ScrapedDuck API.
    /// </summary>
    public interface IScrapedDuckClient
    {
        /// <summary>
        /// Fetches all events from the ScrapedDuck API, parses them into normalised models.
        /// </summary>
        Task<IReadOnlyList<ParsedEvent>> FetchEventsAsync(CancellationToken cancellationToken = default);
    }
}
