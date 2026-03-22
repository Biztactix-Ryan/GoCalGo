using GoCalGo.Contracts.Events;

namespace GoCalGo.Api.Tests.Infrastructure.Builders
{
    /// <summary>
    /// Fluent builder for creating <see cref="EventDto"/> instances in tests.
    /// </summary>
    public sealed class EventDtoBuilder
    {
        private string _id = Guid.NewGuid().ToString();
        private string _name = "Test Event";
        private EventTypeDto _eventType = EventTypeDto.Event;
        private string _heading = "Test Heading";
        private string _imageUrl = "https://example.com/image.png";
        private string _linkUrl = "https://example.com/link";
        private DateTime? _start;
        private DateTime? _end;
        private bool _isUtcTime;
        private bool _hasSpawns;
        private bool _hasResearchTasks;
        private IReadOnlyList<BuffDto> _buffs = [];
        private IReadOnlyList<PokemonDto> _featuredPokemon = [];
        private IReadOnlyList<string> _promoCodes = [];

        public EventDtoBuilder WithId(string id) { _id = id; return this; }
        public EventDtoBuilder WithName(string name) { _name = name; return this; }
        public EventDtoBuilder WithEventType(EventTypeDto type) { _eventType = type; return this; }
        public EventDtoBuilder WithHeading(string heading) { _heading = heading; return this; }
        public EventDtoBuilder WithImageUrl(string url) { _imageUrl = url; return this; }
        public EventDtoBuilder WithLinkUrl(string url) { _linkUrl = url; return this; }
        public EventDtoBuilder WithStart(DateTime start) { _start = start; return this; }
        public EventDtoBuilder WithEnd(DateTime end) { _end = end; return this; }
        public EventDtoBuilder WithTimeRange(DateTime start, DateTime end)
        {
            _start = start;
            _end = end;
            return this;
        }
        public EventDtoBuilder WithIsUtcTime(bool isUtc = true) { _isUtcTime = isUtc; return this; }
        public EventDtoBuilder WithHasSpawns(bool has = true) { _hasSpawns = has; return this; }
        public EventDtoBuilder WithHasResearchTasks(bool has = true) { _hasResearchTasks = has; return this; }
        public EventDtoBuilder WithBuffs(params BuffDto[] buffs) { _buffs = buffs; return this; }
        public EventDtoBuilder WithFeaturedPokemon(params PokemonDto[] pokemon) { _featuredPokemon = pokemon; return this; }
        public EventDtoBuilder WithPromoCodes(params string[] codes) { _promoCodes = codes; return this; }

        public EventDto Build()
        {
            return new()
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
                FeaturedPokemon = _featuredPokemon,
                PromoCodes = _promoCodes,
            };
        }
    }
}
