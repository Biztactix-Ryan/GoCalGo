using GoCalGo.Api.Models;

namespace GoCalGo.Api.Services
{
    /// <summary>
    /// Manages the lifecycle of scheduled notifications — storing, querying,
    /// and cancelling them when events are unflagged.
    /// </summary>
    public interface INotificationStore
    {
        /// <summary>
        /// Persists a scheduled notification so it can be sent at the scheduled time.
        /// </summary>
        Task ScheduleAsync(ScheduledNotification notification);

        /// <summary>
        /// Cancels all pending notifications for a given event and device.
        /// Called when a user unflags an event.
        /// </summary>
        /// <returns>The number of notifications cancelled.</returns>
        Task<int> CancelByEventAndDeviceAsync(string eventId, int deviceTokenId);

        /// <summary>
        /// Returns all pending notifications for a given device.
        /// </summary>
        Task<IReadOnlyList<ScheduledNotification>> GetPendingByDeviceAsync(int deviceTokenId);
    }
}
