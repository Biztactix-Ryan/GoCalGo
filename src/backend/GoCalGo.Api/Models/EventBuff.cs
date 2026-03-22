namespace GoCalGo.Api.Models
{
    public class EventBuff
    {
        public int Id { get; set; }
        public string EventId { get; set; } = string.Empty;
        public string Text { get; set; } = string.Empty;
        public string? IconUrl { get; set; }
        public BuffCategory Category { get; set; }
        public double? Multiplier { get; set; }
        public string? Resource { get; set; }
        public string? Disclaimer { get; set; }

        public Event Event { get; set; } = null!;
    }
}
