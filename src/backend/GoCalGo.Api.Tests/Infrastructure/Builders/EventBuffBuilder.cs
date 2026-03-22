using GoCalGo.Api.Models;

namespace GoCalGo.Api.Tests.Infrastructure.Builders
{
    /// <summary>
    /// Fluent builder for creating <see cref="EventBuff"/> instances in tests.
    /// </summary>
    public sealed class EventBuffBuilder
    {
        private string _eventId = string.Empty;
        private string _text = "2× Catch XP";
        private string? _iconUrl = "https://example.com/icon.png";
        private BuffCategory _category = BuffCategory.Multiplier;
        private double? _multiplier = 2.0;
        private string? _resource = "XP";
        private string? _disclaimer;

        public EventBuffBuilder WithEventId(string id) { _eventId = id; return this; }
        public EventBuffBuilder WithText(string text) { _text = text; return this; }
        public EventBuffBuilder WithIconUrl(string? url) { _iconUrl = url; return this; }
        public EventBuffBuilder WithCategory(BuffCategory category) { _category = category; return this; }
        public EventBuffBuilder WithMultiplier(double? multiplier) { _multiplier = multiplier; return this; }
        public EventBuffBuilder WithResource(string? resource) { _resource = resource; return this; }
        public EventBuffBuilder WithDisclaimer(string? disclaimer) { _disclaimer = disclaimer; return this; }

        public EventBuff Build()
        {
            return new()
            {
                EventId = _eventId,
                Text = _text,
                IconUrl = _iconUrl,
                Category = _category,
                Multiplier = _multiplier,
                Resource = _resource,
                Disclaimer = _disclaimer,
            };
        }

        /// <summary>Creates a 2× XP multiplier buff.</summary>
        public static EventBuffBuilder DoubleXp()
        {
            return new EventBuffBuilder()
                .WithText("2× Catch XP")
                .WithCategory(BuffCategory.Multiplier)
                .WithMultiplier(2.0)
                .WithResource("XP");
        }

        /// <summary>Creates a 3× Stardust multiplier buff.</summary>
        public static EventBuffBuilder TripleStardust()
        {
            return new EventBuffBuilder()
                .WithText("3× Catch Stardust")
                .WithCategory(BuffCategory.Multiplier)
                .WithMultiplier(3.0)
                .WithResource("Stardust");
        }

        /// <summary>Creates a spawn-type buff.</summary>
        public static EventBuffBuilder IncreasedSpawns()
        {
            return new EventBuffBuilder()
                .WithText("Increased wild spawns")
                .WithCategory(BuffCategory.Spawn)
                .WithMultiplier(null)
                .WithResource(null)
                .WithIconUrl(null);
        }
    }
}
