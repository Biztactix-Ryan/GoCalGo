using System.Diagnostics;
using System.Text.Json;
using GoCalGo.Api.Configuration;
using Microsoft.Extensions.Options;

namespace GoCalGo.Api.Services
{
    /// <summary>
    /// HTTP client that fetches event data from the ScrapedDuck JSON API,
    /// handles errors/timeouts/malformed responses, and parses into internal models.
    /// </summary>
    public sealed partial class ScrapedDuckClient(
        HttpClient httpClient,
        IOptions<ScrapedDuckSettings> settings,
        ILogger<ScrapedDuckClient> logger) : IScrapedDuckClient
    {
        public async Task<IReadOnlyList<ParsedEvent>> FetchEventsAsync(CancellationToken cancellationToken = default)
        {
            string url = $"{settings.Value.BaseUrl}/data/events.json";
            LogFetchStarting(logger, url);

            Stopwatch sw = Stopwatch.StartNew();
            HttpResponseMessage response;

            try
            {
                response = await httpClient.GetAsync(url, cancellationToken);
            }
            catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
            {
                sw.Stop();
                LogFetchTimeout(logger, url, sw.ElapsedMilliseconds);
                throw new ScrapedDuckClientException("Request to ScrapedDuck API timed out.", ex);
            }
            catch (HttpRequestException ex)
            {
                sw.Stop();
                LogFetchHttpError(logger, ex, url, sw.ElapsedMilliseconds);
                throw new ScrapedDuckClientException("HTTP error communicating with ScrapedDuck API.", ex);
            }

            if (!response.IsSuccessStatusCode)
            {
                sw.Stop();
                LogFetchBadStatus(logger, (int)response.StatusCode, url, sw.ElapsedMilliseconds);
                throw new ScrapedDuckClientException(
                    $"ScrapedDuck API returned HTTP {(int)response.StatusCode} ({response.StatusCode}).");
            }

            JsonDocument doc;
            try
            {
                await using Stream stream = await response.Content.ReadAsStreamAsync(cancellationToken);
                doc = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            }
            catch (JsonException ex)
            {
                sw.Stop();
                LogFetchMalformedJson(logger, ex, url, sw.ElapsedMilliseconds);
                throw new ScrapedDuckClientException("ScrapedDuck API returned malformed JSON.", ex);
            }

            using (doc)
            {
                if (doc.RootElement.ValueKind != JsonValueKind.Array)
                {
                    sw.Stop();
                    LogFetchUnexpectedShape(logger, doc.RootElement.ValueKind.ToString(), url, sw.ElapsedMilliseconds);
                    throw new ScrapedDuckClientException(
                        $"Expected JSON array from ScrapedDuck API but got {doc.RootElement.ValueKind}.");
                }

                IReadOnlyList<ParsedEvent> events = ScrapedDuckEventParser.ParseAll(doc.RootElement);
                sw.Stop();

                LogFetchCompleted(logger, events.Count, sw.ElapsedMilliseconds);
                return events;
            }
        }

        [LoggerMessage(Level = LogLevel.Information, Message = "ScrapedDuck client: fetching events from {Url}")]
        private static partial void LogFetchStarting(ILogger logger, string url);

        [LoggerMessage(Level = LogLevel.Information, Message = "ScrapedDuck client: fetched and parsed {EventCount} events in {ElapsedMs}ms")]
        private static partial void LogFetchCompleted(ILogger logger, int eventCount, long elapsedMs);

        [LoggerMessage(Level = LogLevel.Error, Message = "ScrapedDuck client: request to {Url} timed out after {ElapsedMs}ms")]
        private static partial void LogFetchTimeout(ILogger logger, string url, long elapsedMs);

        [LoggerMessage(Level = LogLevel.Error, Message = "ScrapedDuck client: HTTP error fetching {Url} after {ElapsedMs}ms")]
        private static partial void LogFetchHttpError(ILogger logger, Exception ex, string url, long elapsedMs);

        [LoggerMessage(Level = LogLevel.Error, Message = "ScrapedDuck client: received HTTP {StatusCode} from {Url} after {ElapsedMs}ms")]
        private static partial void LogFetchBadStatus(ILogger logger, int statusCode, string url, long elapsedMs);

        [LoggerMessage(Level = LogLevel.Error, Message = "ScrapedDuck client: malformed JSON from {Url} after {ElapsedMs}ms")]
        private static partial void LogFetchMalformedJson(ILogger logger, Exception ex, string url, long elapsedMs);

        [LoggerMessage(Level = LogLevel.Error, Message = "ScrapedDuck client: unexpected JSON shape '{Shape}' from {Url} after {ElapsedMs}ms")]
        private static partial void LogFetchUnexpectedShape(ILogger logger, string shape, string url, long elapsedMs);
    }

    /// <summary>
    /// Thrown when the ScrapedDuck API client encounters a non-recoverable error.
    /// </summary>
    public class ScrapedDuckClientException : Exception
    {
        public ScrapedDuckClientException(string message) : base(message) { }
        public ScrapedDuckClientException(string message, Exception innerException) : base(message, innerException) { }
    }
}
