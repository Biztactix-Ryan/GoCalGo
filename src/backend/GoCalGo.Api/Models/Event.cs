namespace GoCalGo.Api.Models
{
    public class Event
    {
        public string Id { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public EventType EventType { get; set; }
        public string Heading { get; set; } = string.Empty;
        public string ImageUrl { get; set; } = string.Empty;
        public string LinkUrl { get; set; } = string.Empty;
        public DateTime? Start { get; set; }
        public DateTime? End { get; set; }
        public bool IsUtcTime { get; set; }
        public bool HasSpawns { get; set; }
        public bool HasResearchTasks { get; set; }

        public List<EventBuff> Buffs { get; set; } = [];
    }
}
