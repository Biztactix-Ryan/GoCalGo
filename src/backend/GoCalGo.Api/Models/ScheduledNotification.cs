namespace GoCalGo.Api.Models
{
    public class ScheduledNotification
    {
        public int Id { get; set; }
        public string EventId { get; set; } = string.Empty;
        public string EventName { get; set; } = string.Empty;
        public int DeviceTokenId { get; set; }
        public DateTime ScheduledAtUtc { get; set; }
        public TimeSpan RemainingTime { get; set; }
        public NotificationStatus Status { get; set; } = NotificationStatus.Pending;
        public DateTime CreatedAtUtc { get; set; }
    }
}
