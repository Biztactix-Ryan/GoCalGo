namespace GoCalGo.Api.Models
{
    public class EventFlag
    {
        /// <summary>Allowed lead-time values in minutes.</summary>
        public static readonly int[] AllowedLeadTimeMinutes = [5, 15, 30, 60];

        public int Id { get; set; }
        public string EventId { get; set; } = string.Empty;
        public string DeviceToken { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }

        /// <summary>
        /// How many minutes before the event ends the user wants to be notified.
        /// Must be one of: 5, 15, 30, 60. Defaults to 15.
        /// </summary>
        public int LeadTimeMinutes { get; set; } = 15;
    }
}
