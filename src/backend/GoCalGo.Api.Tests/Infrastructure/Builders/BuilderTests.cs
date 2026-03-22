using GoCalGo.Api.Models;
using GoCalGo.Contracts.Events;

namespace GoCalGo.Api.Tests.Infrastructure.Builders
{
    public sealed class BuilderTests
    {
        [Fact]
        public void EventBuilder_defaults_produce_valid_event()
        {
            Event ev = A.Event.Build();

            Assert.NotEmpty(ev.Id);
            Assert.Equal("Test Event", ev.Name);
            Assert.Equal(EventType.Event, ev.EventType);
            Assert.Empty(ev.Buffs);
        }

        [Fact]
        public void EventBuilder_fluent_overrides_work()
        {
            Event ev = A.Event
                .WithId("my-id")
                .WithName("Go Fest")
                .WithEventType(EventType.PokemonGoFest)
                .WithHasSpawns()
                .Build();

            Assert.Equal("my-id", ev.Id);
            Assert.Equal("Go Fest", ev.Name);
            Assert.Equal(EventType.PokemonGoFest, ev.EventType);
            Assert.True(ev.HasSpawns);
        }

        [Fact]
        public void EventBuilder_WithBuff_links_buff_to_event()
        {
            Event ev = A.Event
                .WithId("ev-1")
                .WithBuff(b => b.WithText("2× XP").WithMultiplier(2.0))
                .Build();

            Assert.Single(ev.Buffs);
            Assert.Equal("ev-1", ev.Buffs[0].EventId);
            Assert.Equal(ev, ev.Buffs[0].Event);
            Assert.Equal("2× XP", ev.Buffs[0].Text);
        }

        [Fact]
        public void EventBuilder_preset_CommunityDay()
        {
            Event ev = EventBuilder.CommunityDay().Build();

            Assert.Equal(EventType.CommunityDay, ev.EventType);
            Assert.True(ev.HasSpawns);
            Assert.NotNull(ev.Start);
            Assert.NotNull(ev.End);
        }

        [Fact]
        public void EventBuilder_preset_Active_has_correct_time_range()
        {
            Event ev = EventBuilder.Active().Build();

            Assert.NotNull(ev.Start);
            Assert.NotNull(ev.End);
            Assert.True(ev.Start < DateTime.UtcNow);
            Assert.True(ev.End > DateTime.UtcNow);
        }

        [Fact]
        public void EventBuffBuilder_defaults_produce_valid_buff()
        {
            EventBuff buff = A.EventBuff.Build();

            Assert.Equal("2× Catch XP", buff.Text);
            Assert.Equal(GoCalGo.Api.Models.BuffCategory.Multiplier, buff.Category);
            Assert.Equal(2.0, buff.Multiplier);
        }

        [Fact]
        public void EventBuffBuilder_preset_TripleStardust()
        {
            EventBuff buff = EventBuffBuilder.TripleStardust().Build();

            Assert.Equal(3.0, buff.Multiplier);
            Assert.Equal("Stardust", buff.Resource);
        }

        [Fact]
        public void EventDtoBuilder_defaults_produce_valid_dto()
        {
            EventDto dto = A.EventDto.Build();

            Assert.NotEmpty(dto.Id);
            Assert.Equal("Test Event", dto.Name);
            Assert.Empty(dto.Buffs);
            Assert.Empty(dto.FeaturedPokemon);
            Assert.Empty(dto.PromoCodes);
        }

        [Fact]
        public void PokemonDtoBuilder_defaults_produce_valid_dto()
        {
            PokemonDto pokemon = A.PokemonDto.Build();

            Assert.Equal("Bulbasaur", pokemon.Name);
            Assert.Equal(PokemonRole.Spawn, pokemon.Role);
            Assert.False(pokemon.CanBeShiny);
        }

        [Fact]
        public void EventDtoBuilder_with_nested_data()
        {
            EventDto dto = A.EventDto
                .WithId("fest-1")
                .WithBuffs(new BuffDto
                {
                    Text = "2× XP",
                    Category = GoCalGo.Contracts.Events.BuffCategory.Multiplier,
                    Multiplier = 2.0,
                })
                .WithFeaturedPokemon(A.PokemonDto.WithCanBeShiny().Build())
                .WithPromoCodes("CODE1")
                .Build();

            Assert.Single(dto.Buffs);
            Assert.Single(dto.FeaturedPokemon);
            Assert.True(dto.FeaturedPokemon[0].CanBeShiny);
            Assert.Single(dto.PromoCodes);
        }
    }
}
