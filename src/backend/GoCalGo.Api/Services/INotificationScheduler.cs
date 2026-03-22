using GoCalGo.Api.Models;

namespace GoCalGo.Api.Services
{
    /// <summary>
    /// Calculates when a push notification should be sent for a flagged event,
    /// accounting for the user's local timezone.
    /// </summary>
    public interface INotificationScheduler
    {
        /// <summary>
        /// Determines the UTC instant at which a notification should be sent
        /// for the given event and device, applying the configured buffer.
        /// </summary>
        ScheduledNotification CalculateNotificationTime(
            Event flaggedEvent,
            DeviceToken device,
            TimeSpan buffer);
    }
}
