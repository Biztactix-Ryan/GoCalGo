using System.Globalization;
using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace GoCalGo.Api.Services
{
    /// <summary>
    /// Background service that monitors flagged events, schedules notifications,
    /// and sends them via FCM when the scheduled time arrives.
    /// </summary>
    public sealed partial class NotificationSchedulerJob(
        IServiceScopeFactory scopeFactory,
        ILogger<NotificationSchedulerJob> logger) : BackgroundService
    {
        private static readonly TimeSpan PollInterval = TimeSpan.FromMinutes(1);

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            LogJobStarted(logger);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    using IServiceScope scope = scopeFactory.CreateScope();
                    GoCalGoDbContext db = scope.ServiceProvider.GetRequiredService<GoCalGoDbContext>();
                    INotificationScheduler scheduler = scope.ServiceProvider.GetRequiredService<INotificationScheduler>();
                    INotificationStore store = scope.ServiceProvider.GetRequiredService<INotificationStore>();

                    await ScheduleNewNotificationsAsync(db, scheduler, store, stoppingToken);
                    await SendDueNotificationsAsync(db, stoppingToken);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    LogIterationFailed(logger, ex);
                }

                await Task.Delay(PollInterval, stoppingToken);
            }
        }

        /// <summary>
        /// Finds flagged events that don't yet have a pending notification scheduled
        /// and creates one for each.
        /// </summary>
        private async Task ScheduleNewNotificationsAsync(
            GoCalGoDbContext db,
            INotificationScheduler scheduler,
            INotificationStore store,
            CancellationToken ct)
        {
            List<EventFlag> flags = await db.EventFlags
                .AsNoTracking()
                .ToListAsync(ct);

            if (flags.Count == 0)
            {
                return;
            }

            List<string> deviceTokenValues = [.. flags.Select(f => f.DeviceToken).Distinct()];
            Dictionary<string, DeviceToken> devices = await db.DeviceTokens
                .Where(d => deviceTokenValues.Contains(d.Token))
                .AsNoTracking()
                .ToDictionaryAsync(d => d.Token, ct);

            // Load global notification preferences per device
            Dictionary<string, NotificationPreference> preferences = await db.NotificationPreferences
                .Where(p => deviceTokenValues.Contains(p.DeviceToken))
                .AsNoTracking()
                .ToDictionaryAsync(p => p.DeviceToken, ct);

            List<string> eventIds = [.. flags.Select(f => f.EventId).Distinct()];
            Dictionary<string, Event> events = await db.Events
                .Where(e => eventIds.Contains(e.Id))
                .AsNoTracking()
                .ToDictionaryAsync(e => e.Id, ct);

            List<ScheduledNotification> existingNotifications = await db.ScheduledNotifications
                .Where(n => n.Status == NotificationStatus.Pending)
                .AsNoTracking()
                .ToListAsync(ct);

            HashSet<(string EventId, int DeviceTokenId)> existingSet = [.. existingNotifications
                .Select(n => (n.EventId, n.DeviceTokenId))];

            int scheduled = 0;
            foreach (EventFlag flag in flags)
            {
                if (!devices.TryGetValue(flag.DeviceToken, out DeviceToken? device))
                {
                    continue;
                }

                if (!events.TryGetValue(flag.EventId, out Event? ev))
                {
                    continue;
                }

                // Check global notification preferences for this device
                if (preferences.TryGetValue(flag.DeviceToken, out NotificationPreference? pref))
                {
                    // Skip if notifications are globally disabled
                    if (!pref.Enabled)
                    {
                        continue;
                    }

                    // Skip if this event's type is not in the enabled event types.
                    // The app sends kebab-case values (e.g. "community-day") which are stored as-is.
                    // Convert the C# enum name (e.g. "CommunityDay") to kebab-case for comparison.
                    if (!string.IsNullOrEmpty(pref.EnabledEventTypes))
                    {
                        HashSet<string> enabledTypes = [.. pref.EnabledEventTypes.Split(',', StringSplitOptions.RemoveEmptyEntries)];
                        string eventTypeKebab = ToKebabCase(ev.EventType.ToString());
                        if (!enabledTypes.Contains(eventTypeKebab))
                        {
                            continue;
                        }
                    }
                }

                if (existingSet.Contains((flag.EventId, device.Id)))
                {
                    continue;
                }

                if (ev.End is null)
                {
                    continue;
                }

                // Check if the notification time has already passed
                TimeSpan leadTime = TimeSpan.FromMinutes(flag.LeadTimeMinutes);
                ScheduledNotification notification;
                try
                {
                    notification = scheduler.CalculateNotificationTime(ev, device, leadTime);
                }
                catch (InvalidOperationException)
                {
                    // Device missing timezone for local event — skip
                    continue;
                }

                if (notification.ScheduledAtUtc < DateTime.UtcNow)
                {
                    continue;
                }

                await store.ScheduleAsync(notification);
                existingSet.Add((flag.EventId, device.Id));
                scheduled++;
            }

            if (scheduled > 0)
            {
                LogNotificationsScheduled(logger, scheduled);
            }
        }

        /// <summary>
        /// Finds pending notifications whose scheduled time has arrived and
        /// sends them via FCM.
        /// </summary>
        private async Task SendDueNotificationsAsync(GoCalGoDbContext db, CancellationToken ct)
        {
            DateTime now = DateTime.UtcNow;

            List<ScheduledNotification> dueNotifications = await db.ScheduledNotifications
                .Where(n => n.Status == NotificationStatus.Pending && n.ScheduledAtUtc <= now)
                .ToListAsync(ct);

            if (dueNotifications.Count == 0)
            {
                return;
            }

            List<int> deviceTokenIds = [.. dueNotifications.Select(n => n.DeviceTokenId).Distinct()];
            Dictionary<int, DeviceToken> deviceTokens = await db.DeviceTokens
                .Where(d => deviceTokenIds.Contains(d.Id))
                .AsNoTracking()
                .ToDictionaryAsync(d => d.Id, ct);

            int sent = 0;
            foreach (ScheduledNotification notification in dueNotifications)
            {
                if (!deviceTokens.TryGetValue(notification.DeviceTokenId, out DeviceToken? device))
                {
                    notification.Status = NotificationStatus.Cancelled;
                    continue;
                }

                try
                {
                    await SendFcmNotificationAsync(notification, device.Token, ct);
                    notification.Status = NotificationStatus.Sent;
                    sent++;
                }
                catch (Exception ex)
                {
                    LogFcmSendFailed(logger, notification.EventName, device.Token, ex);
                    // Leave as Pending to retry on next poll
                }
            }

            await db.SaveChangesAsync(ct);

            if (sent > 0)
            {
                LogNotificationsSent(logger, sent);
            }
        }

        /// <summary>
        /// Sends a push notification via Firebase Cloud Messaging.
        /// </summary>
        private static async Task SendFcmNotificationAsync(
            ScheduledNotification notification,
            string fcmToken,
            CancellationToken ct)
        {
            FirebaseAdmin.Messaging.Message message = new()
            {
                Token = fcmToken,
                Notification = new FirebaseAdmin.Messaging.Notification
                {
                    Title = "Event Ending Soon",
                    Body = $"{notification.EventName} ends in {FormatRemainingTime(notification.RemainingTime)}!",
                },
                Data = new Dictionary<string, string>
                {
                    ["eventId"] = notification.EventId,
                    ["remainingMinutes"] = ((int)notification.RemainingTime.TotalMinutes).ToString(CultureInfo.InvariantCulture),
                },
            };

            await FirebaseAdmin.Messaging.FirebaseMessaging.DefaultInstance.SendAsync(message, ct);
        }

        private static string FormatRemainingTime(TimeSpan remaining)
        {
            return remaining.TotalHours >= 1
                ? $"{(int)remaining.TotalHours}h {remaining.Minutes}m"
                : $"{(int)remaining.TotalMinutes} minutes";
        }

        /// <summary>
        /// Converts a PascalCase string to kebab-case (e.g. "CommunityDay" → "community-day").
        /// </summary>
        private static string ToKebabCase(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return value;
            }

            Span<char> buffer = stackalloc char[value.Length * 2];
            int pos = 0;

            for (int i = 0; i < value.Length; i++)
            {
                char c = value[i];
                if (char.IsUpper(c) && i > 0)
                {
                    buffer[pos++] = '-';
                }
                buffer[pos++] = char.ToLowerInvariant(c);
            }

            return new string(buffer[..pos]);
        }

        [LoggerMessage(Level = LogLevel.Information, Message = "Notification scheduler job started, polling every 1m")]
        private static partial void LogJobStarted(ILogger logger);

        [LoggerMessage(Level = LogLevel.Error, Message = "Notification scheduler job iteration failed")]
        private static partial void LogIterationFailed(ILogger logger, Exception ex);

        [LoggerMessage(Level = LogLevel.Information, Message = "Scheduled {Count} new notifications")]
        private static partial void LogNotificationsScheduled(ILogger logger, int count);

        [LoggerMessage(Level = LogLevel.Information, Message = "Sent {Count} notifications via FCM")]
        private static partial void LogNotificationsSent(ILogger logger, int count);

        [LoggerMessage(Level = LogLevel.Warning, Message = "FCM send failed for event '{EventName}' to token '{Token}'")]
        private static partial void LogFcmSendFailed(ILogger logger, string eventName, string token, Exception ex);
    }
}
