using GoCalGo.Api.Models;

namespace GoCalGo.Api.Services
{
    /// <summary>
    /// Calculates notification send times, converting local wall-clock event
    /// times to the user's timezone before determining the UTC send instant.
    /// </summary>
    public sealed class NotificationScheduler : INotificationScheduler
    {
        public ScheduledNotification CalculateNotificationTime(
            Event flaggedEvent,
            DeviceToken device,
            TimeSpan buffer)
        {
            ArgumentNullException.ThrowIfNull(flaggedEvent);
            ArgumentNullException.ThrowIfNull(device);

            if (flaggedEvent.End is null)
            {
                throw new InvalidOperationException("Cannot schedule notification for event with no end time.");
            }

            DateTime eventEndUtc = ResolveEndTimeUtc(flaggedEvent, device.Timezone);
            DateTime scheduledAtUtc = eventEndUtc - buffer;
            TimeSpan remaining = buffer;

            return new ScheduledNotification
            {
                EventId = flaggedEvent.Id,
                EventName = flaggedEvent.Name,
                DeviceTokenId = device.Id,
                ScheduledAtUtc = scheduledAtUtc,
                RemainingTime = remaining,
            };
        }

        /// <summary>
        /// Resolves the event end time to a UTC instant.
        /// - UTC events: the end time is already UTC.
        /// - Local wall-clock events: the end time is interpreted in the user's
        ///   timezone and converted to UTC, so the notification fires at the
        ///   correct moment for that specific user.
        /// </summary>
        private static DateTime ResolveEndTimeUtc(Event flaggedEvent, string? timezone)
        {
            DateTime end = flaggedEvent.End!.Value;

            if (flaggedEvent.IsUtcTime)
            {
                return DateTime.SpecifyKind(end, DateTimeKind.Utc);
            }

            // Local wall-clock time — needs timezone conversion.
            if (string.IsNullOrWhiteSpace(timezone))
            {
                throw new InvalidOperationException(
                    "Cannot schedule timezone-aware notification: device has no timezone set.");
            }

            TimeZoneInfo tz = TimeZoneInfo.FindSystemTimeZoneById(timezone);
            DateTime unspecified = DateTime.SpecifyKind(end, DateTimeKind.Unspecified);
            DateTimeOffset localOffset = new(unspecified, tz.GetUtcOffset(unspecified));

            return localOffset.UtcDateTime;
        }
    }
}
