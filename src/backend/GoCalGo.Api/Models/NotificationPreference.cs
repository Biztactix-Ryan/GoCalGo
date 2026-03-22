namespace GoCalGo.Api.Models
{
    /// <summary>
    /// Stores global notification preferences for a device, synced from the Flutter app.
    /// These preferences control whether notifications are sent and which event types
    /// trigger them.
    /// </summary>
    public class NotificationPreference
    {
        public int Id { get; set; }

        /// <summary>The FCM device token this preference belongs to.</summary>
        public string DeviceToken { get; set; } = string.Empty;

        /// <summary>Master toggle — when false, no notifications should be sent.</summary>
        public bool Enabled { get; set; } = true;

        /// <summary>
        /// Default lead time in minutes for new flags. Must be one of: 5, 15, 30, 60.
        /// </summary>
        public int LeadTimeMinutes { get; set; } = 15;

        /// <summary>
        /// Comma-separated list of enabled event type JSON values
        /// (e.g. "community-day,raid-hour,event").
        /// </summary>
        public string EnabledEventTypes { get; set; } = string.Empty;

        public DateTime UpdatedAt { get; set; }
    }
}
