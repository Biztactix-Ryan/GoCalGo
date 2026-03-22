using System.Text.Json;
using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace GoCalGo.Api.Services
{
    public sealed partial class ScrapedDuckIngestionService(
        IScrapedDuckClient client,
        GoCalGoDbContext db,
        ICacheService cache,
        IngestionStatusTracker statusTracker,
        ILogger<ScrapedDuckIngestionService> logger)
    {
        private static readonly JsonSerializerOptions CacheJsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        };

        public async Task<IReadOnlyList<ParsedEvent>> FetchEventsAsync(CancellationToken cancellationToken = default)
        {
            try
            {
                IReadOnlyList<ParsedEvent> events = await client.FetchEventsAsync(cancellationToken);

                int upsertCount = await UpsertEventsAsync(events, cancellationToken);
                LogEventsUpserted(logger, upsertCount);

                await RefreshCacheAsync(cancellationToken);
                LogCacheRefreshed(logger);

                statusTracker.LastFetchTime = DateTime.UtcNow;
                statusTracker.LastFetchEventCount = events.Count;
                statusTracker.LastFetchSuccess = true;

                LogIngestionCompleted(logger, events.Count);

                return events;
            }
            catch (Exception ex) when (ex is ScrapedDuckClientException or OperationCanceledException)
            {
                statusTracker.LastFetchTime = DateTime.UtcNow;
                statusTracker.LastFetchSuccess = false;

                LogIngestionFailed(logger, ex);

                throw;
            }
        }

        internal async Task<int> UpsertEventsAsync(IReadOnlyList<ParsedEvent> parsedEvents, CancellationToken cancellationToken = default)
        {
            List<string> incomingIds = [.. parsedEvents.Select(e => e.Id)];

            Dictionary<string, Event> existingEvents = await db.Events
                .Include(e => e.Buffs)
                .Where(e => incomingIds.Contains(e.Id))
                .ToDictionaryAsync(e => e.Id, cancellationToken);

            int upsertCount = 0;

            foreach (ParsedEvent parsed in parsedEvents)
            {
                if (existingEvents.TryGetValue(parsed.Id, out Event? existing))
                {
                    existing.Name = parsed.Name;
                    existing.EventType = parsed.EventType;
                    existing.Heading = parsed.Heading;
                    existing.ImageUrl = parsed.ImageUrl;
                    existing.LinkUrl = parsed.LinkUrl;
                    existing.Start = parsed.Start;
                    existing.End = parsed.End;
                    existing.IsUtcTime = parsed.IsUtcTime;
                    existing.HasSpawns = parsed.HasSpawns;
                    existing.HasResearchTasks = parsed.HasResearchTasks;

                    db.EventBuffs.RemoveRange(existing.Buffs);
                    existing.Buffs = MapBuffs(parsed);
                }
                else
                {
                    Event entity = new()
                    {
                        Id = parsed.Id,
                        Name = parsed.Name,
                        EventType = parsed.EventType,
                        Heading = parsed.Heading,
                        ImageUrl = parsed.ImageUrl,
                        LinkUrl = parsed.LinkUrl,
                        Start = parsed.Start,
                        End = parsed.End,
                        IsUtcTime = parsed.IsUtcTime,
                        HasSpawns = parsed.HasSpawns,
                        HasResearchTasks = parsed.HasResearchTasks,
                        Buffs = MapBuffs(parsed),
                    };
                    db.Events.Add(entity);
                }

                upsertCount++;
            }

            await db.SaveChangesAsync(cancellationToken);
            return upsertCount;
        }

        internal async Task RefreshCacheAsync(CancellationToken cancellationToken = default)
        {
            List<Event> allEvents = await db.Events
                .Include(e => e.Buffs)
                .AsNoTracking()
                .OrderBy(e => e.Start)
                .ToListAsync(cancellationToken);

            string json = JsonSerializer.Serialize(allEvents, CacheJsonOptions);
            await cache.SetAsync(CacheKeys.EventsAll, json);
        }

        private static List<EventBuff> MapBuffs(ParsedEvent parsed)
        {
            return [.. parsed.Buffs.Select(b => new EventBuff
            {
                EventId = parsed.Id,
                Text = b.Text,
                IconUrl = b.IconUrl,
                Category = b.Category,
                Multiplier = b.Multiplier,
                Resource = b.Resource,
                Disclaimer = b.Disclaimer,
            })];
        }

        [LoggerMessage(Level = LogLevel.Information, Message = "Ingestion completed: {EventCount} events fetched")]
        private static partial void LogIngestionCompleted(ILogger logger, int eventCount);

        [LoggerMessage(Level = LogLevel.Information, Message = "{UpsertCount} events upserted to database")]
        private static partial void LogEventsUpserted(ILogger logger, int upsertCount);

        [LoggerMessage(Level = LogLevel.Information, Message = "Redis cache refreshed with latest event data")]
        private static partial void LogCacheRefreshed(ILogger logger);

        [LoggerMessage(Level = LogLevel.Error, Message = "Ingestion failed")]
        private static partial void LogIngestionFailed(ILogger logger, Exception ex);
    }
}
