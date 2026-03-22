namespace GoCalGo.Api.Services
{
    public class IngestionStatusTracker
    {
        public DateTime? LastFetchTime { get; set; }
        public int? LastFetchEventCount { get; set; }
        public bool? LastFetchSuccess { get; set; }
    }
}
