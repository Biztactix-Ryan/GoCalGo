using GoCalGo.Api.Models;

namespace GoCalGo.Api.Tests.Infrastructure.Builders
{
    /// <summary>
    /// Fluent builder for creating <see cref="Event"/> instances in tests.
    /// Provides sensible defaults so tests only need to specify what matters.
    /// </summary>
    public sealed class EventBuilder
    {
        private string _id = Guid.NewGuid().ToString();
        private string _name = "Test Event";
        private EventType _eventType = EventType.Event;
        private string _heading = "Test Heading";
        private string _imageUrl = "https://example.com/image.png";
        private string _linkUrl = "https://example.com/link";
        private DateTime? _start;
        private DateTime? _end;
        private bool _isUtcTime;
        private bool _hasSpawns;
        private bool _hasResearchTasks;
        private List<EventBuff> _buffs = [];

        public EventBuilder WithId(string id) { _id = id; return this; }
        public EventBuilder WithName(string name) { _name = name; return this; }
        public EventBuilder WithEventType(EventType type) { _eventType = type; return this; }
        public EventBuilder WithHeading(string heading) { _heading = heading; return this; }
        public EventBuilder WithImageUrl(string url) { _imageUrl = url; return this; }
        public EventBuilder WithLinkUrl(string url) { _linkUrl = url; return this; }
        public EventBuilder WithStart(DateTime start) { _start = start; return this; }
        public EventBuilder WithEnd(DateTime end) { _end = end; return this; }
        public EventBuilder WithTimeRange(DateTime start, DateTime end)
        {
            _start = start;
            _end = end;
            return this;
        }
        public EventBuilder WithIsUtcTime(bool isUtc = true) { _isUtcTime = isUtc; return this; }
        public EventBuilder WithHasSpawns(bool hasSpawns = true) { _hasSpawns = hasSpawns; return this; }
        public EventBuilder WithHasResearchTasks(bool has = true) { _hasResearchTasks = has; return this; }
        public EventBuilder WithBuffs(params EventBuff[] buffs) { _buffs = [.. buffs]; return this; }
        public EventBuilder WithBuff(Action<EventBuffBuilder> configure)
        {
            EventBuffBuilder builder = new();
            configure(builder);
            _buffs.Add(builder.Build());
            return this;
        }

        public Event Build()
        {
            Event ev = new()
            {
                Id = _id,
                Name = _name,
                EventType = _eventType,
                Heading = _heading,
                ImageUrl = _imageUrl,
                LinkUrl = _linkUrl,
                Start = _start,
                End = _end,
                IsUtcTime = _isUtcTime,
                HasSpawns = _hasSpawns,
                HasResearchTasks = _hasResearchTasks,
                Buffs = _buffs,
            };

            // Back-link buffs to the event
            foreach (EventBuff buff in _buffs)
            {
                buff.EventId = ev.Id;
                buff.Event = ev;
            }

            return ev;
        }

        /// <summary>Creates a community day event with typical defaults.</summary>
        public static EventBuilder CommunityDay()
        {
            return new EventBuilder()
                .WithName("Community Day: March 2026")
                .WithEventType(EventType.CommunityDay)
                .WithHeading("Featuring Bulbasaur")
                .WithHasSpawns()
                .WithIsUtcTime(false)
                .WithTimeRange(
                    new DateTime(2026, 3, 14, 14, 0, 0, DateTimeKind.Utc),
                    new DateTime(2026, 3, 14, 17, 0, 0, DateTimeKind.Utc));
        }

        /// <summary>Creates a spotlight hour event with typical defaults.</summary>
        public static EventBuilder SpotlightHour()
        {
            return new EventBuilder()
                .WithName("Spotlight Hour")
                .WithEventType(EventType.SpotlightHour)
                .WithHeading("Featuring Pikachu")
                .WithHasSpawns()
                .WithIsUtcTime(false)
                .WithTimeRange(
                    new DateTime(2026, 3, 17, 18, 0, 0, DateTimeKind.Utc),
                    new DateTime(2026, 3, 17, 19, 0, 0, DateTimeKind.Utc));
        }

        /// <summary>Creates a currently-active event (started yesterday, ends tomorrow).</summary>
        public static EventBuilder Active()
        {
            return new EventBuilder()
                .WithName("Active Test Event")
                .WithIsUtcTime()
                .WithTimeRange(DateTime.UtcNow.AddDays(-1), DateTime.UtcNow.AddDays(1));
        }

        /// <summary>Creates an event that has already ended.</summary>
        public static EventBuilder Past()
        {
            return new EventBuilder()
                .WithName("Past Test Event")
                .WithIsUtcTime()
                .WithTimeRange(DateTime.UtcNow.AddDays(-7), DateTime.UtcNow.AddDays(-1));
        }

        /// <summary>Creates an event that hasn't started yet.</summary>
        public static EventBuilder Future()
        {
            return new EventBuilder()
                .WithName("Future Test Event")
                .WithIsUtcTime()
                .WithTimeRange(DateTime.UtcNow.AddDays(1), DateTime.UtcNow.AddDays(7));
        }
    }
}
