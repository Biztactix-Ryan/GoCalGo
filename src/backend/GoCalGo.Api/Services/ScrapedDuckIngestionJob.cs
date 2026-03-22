using GoCalGo.Api.Configuration;
using Microsoft.Extensions.Options;

namespace GoCalGo.Api.Services
{
    public sealed partial class ScrapedDuckIngestionJob(
        IServiceScopeFactory scopeFactory,
        IOptions<ScrapedDuckSettings> settings,
        ILogger<ScrapedDuckIngestionJob> logger) : BackgroundService
    {
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            TimeSpan interval = TimeSpan.FromMinutes(settings.Value.ScheduleIntervalMinutes);
            LogJobStarted(logger, settings.Value.ScheduleIntervalMinutes);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    using IServiceScope scope = scopeFactory.CreateScope();
                    ScrapedDuckIngestionService ingestionService = scope.ServiceProvider.GetRequiredService<ScrapedDuckIngestionService>();
                    await ingestionService.FetchEventsAsync(stoppingToken);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    LogIterationFailed(logger, ex);
                }

                await Task.Delay(interval, stoppingToken);
            }
        }

        [LoggerMessage(Level = LogLevel.Information, Message = "ScrapedDuck ingestion job started with interval {IntervalMinutes}m")]
        private static partial void LogJobStarted(ILogger logger, int intervalMinutes);

        [LoggerMessage(Level = LogLevel.Error, Message = "ScrapedDuck ingestion job iteration failed")]
        private static partial void LogIterationFailed(ILogger logger, Exception ex);
    }
}
