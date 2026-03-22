using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace GoCalGo.Api.Tests.Data
{
    public class EventStorageTests : IDisposable
    {
        private readonly GoCalGoDbContext _context;

        public EventStorageTests()
        {
            DbContextOptions<GoCalGoDbContext> options = new DbContextOptionsBuilder<GoCalGoDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            _context = new GoCalGoDbContext(options);
        }

        public void Dispose()
        {
            _context.Dispose();
            GC.SuppressFinalize(this);
        }

        [Fact]
        public async Task SavedEvent_PersistsName()
        {
            Event ev = MakeEvent();
            ev.Name = "Community Day: Mudkip";

            _context.Events.Add(ev);
            await _context.SaveChangesAsync();

            Event stored = await _context.Events.FirstAsync(e => e.Id == ev.Id);
            Assert.Equal("Community Day: Mudkip", stored.Name);
        }

        [Fact]
        public async Task SavedEvent_PersistsEventType()
        {
            Event ev = MakeEvent();
            ev.EventType = EventType.CommunityDay;

            _context.Events.Add(ev);
            await _context.SaveChangesAsync();

            Event stored = await _context.Events.FirstAsync(e => e.Id == ev.Id);
            Assert.Equal(EventType.CommunityDay, stored.EventType);
        }

        [Fact]
        public async Task SavedEvent_PersistsStartAndEndDates()
        {
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 15, 14, 0, 0, DateTimeKind.Utc);
            ev.End = new DateTime(2026, 3, 15, 17, 0, 0, DateTimeKind.Utc);

            _context.Events.Add(ev);
            await _context.SaveChangesAsync();

            Event stored = await _context.Events.FirstAsync(e => e.Id == ev.Id);
            Assert.Equal(new DateTime(2026, 3, 15, 14, 0, 0, DateTimeKind.Utc), stored.Start);
            Assert.Equal(new DateTime(2026, 3, 15, 17, 0, 0, DateTimeKind.Utc), stored.End);
        }

        [Fact]
        public async Task SavedEvent_PersistsNullDates()
        {
            Event ev = MakeEvent();
            ev.Start = null;
            ev.End = null;

            _context.Events.Add(ev);
            await _context.SaveChangesAsync();

            Event stored = await _context.Events.FirstAsync(e => e.Id == ev.Id);
            Assert.Null(stored.Start);
            Assert.Null(stored.End);
        }

        [Fact]
        public async Task SavedEvent_PersistsBuffs()
        {
            Event ev = MakeEvent();
            ev.Buffs =
            [
                new EventBuff
                {
                    EventId = ev.Id,
                    Text = "3× Catch Stardust",
                    Category = BuffCategory.Multiplier,
                    Multiplier = 3.0,
                    Resource = "Catch Stardust",
                },
                new EventBuff
                {
                    EventId = ev.Id,
                    Text = "Lure Modules last 3 hours",
                    Category = BuffCategory.Duration,
                },
            ];

            _context.Events.Add(ev);
            await _context.SaveChangesAsync();

            Event stored = await _context.Events
                .Include(e => e.Buffs)
                .FirstAsync(e => e.Id == ev.Id);

            Assert.Equal(2, stored.Buffs.Count);
            Assert.Contains(stored.Buffs, b => b.Text == "3× Catch Stardust" && b.Multiplier == 3.0);
            Assert.Contains(stored.Buffs, b => b.Text == "Lure Modules last 3 hours" && b.Category == BuffCategory.Duration);
        }

        [Fact]
        public async Task SavedEvent_PersistsAllEventTypes()
        {
            foreach (EventType eventType in Enum.GetValues<EventType>())
            {
                Event ev = MakeEvent();
                ev.Id = $"type-{eventType}";
                ev.EventType = eventType;
                _context.Events.Add(ev);
            }

            await _context.SaveChangesAsync();

            foreach (EventType eventType in Enum.GetValues<EventType>())
            {
                Event stored = await _context.Events.FirstAsync(e => e.Id == $"type-{eventType}");
                Assert.Equal(eventType, stored.EventType);
            }
        }

        [Fact]
        public async Task SavedEvent_PersistsBuffCategories()
        {
            Event ev = MakeEvent();
            ev.Buffs = [.. Enum.GetValues<BuffCategory>()
                .Select(cat => new EventBuff
                {
                    EventId = ev.Id,
                    Text = $"Buff for {cat}",
                    Category = cat,
                })];

            _context.Events.Add(ev);
            await _context.SaveChangesAsync();

            Event stored = await _context.Events
                .Include(e => e.Buffs)
                .FirstAsync(e => e.Id == ev.Id);

            foreach (BuffCategory cat in Enum.GetValues<BuffCategory>())
            {
                Assert.Contains(stored.Buffs, b => b.Category == cat);
            }
        }

        [Fact]
        public async Task SavedEvent_PersistsAllFields()
        {
            Event ev = new()
            {
                Id = "full-event-1",
                Name = "GO Fest 2026",
                EventType = EventType.PokemonGoFest,
                Heading = "The biggest event of the year!",
                ImageUrl = "https://example.com/gofest.png",
                LinkUrl = "https://example.com/gofest",
                Start = new DateTime(2026, 7, 1, 10, 0, 0, DateTimeKind.Utc),
                End = new DateTime(2026, 7, 2, 18, 0, 0, DateTimeKind.Utc),
                IsUtcTime = true,
                HasSpawns = true,
                HasResearchTasks = true,
                Buffs =
                [
                    new EventBuff
                    {
                        EventId = "full-event-1",
                        Text = "2× Hatch Stardust",
                        IconUrl = "https://example.com/icon.png",
                        Category = BuffCategory.Multiplier,
                        Multiplier = 2.0,
                        Resource = "Hatch Stardust",
                        Disclaimer = "Only during event hours",
                    },
                ],
            };

            _context.Events.Add(ev);
            await _context.SaveChangesAsync();

            Event stored = await _context.Events
                .Include(e => e.Buffs)
                .FirstAsync(e => e.Id == "full-event-1");

            Assert.Equal("GO Fest 2026", stored.Name);
            Assert.Equal(EventType.PokemonGoFest, stored.EventType);
            Assert.Equal("The biggest event of the year!", stored.Heading);
            Assert.Equal("https://example.com/gofest.png", stored.ImageUrl);
            Assert.Equal("https://example.com/gofest", stored.LinkUrl);
            Assert.Equal(new DateTime(2026, 7, 1, 10, 0, 0, DateTimeKind.Utc), stored.Start);
            Assert.Equal(new DateTime(2026, 7, 2, 18, 0, 0, DateTimeKind.Utc), stored.End);
            Assert.True(stored.IsUtcTime);
            Assert.True(stored.HasSpawns);
            Assert.True(stored.HasResearchTasks);

            EventBuff buff = Assert.Single(stored.Buffs);
            Assert.Equal("2× Hatch Stardust", buff.Text);
            Assert.Equal("https://example.com/icon.png", buff.IconUrl);
            Assert.Equal(BuffCategory.Multiplier, buff.Category);
            Assert.Equal(2.0, buff.Multiplier);
            Assert.Equal("Hatch Stardust", buff.Resource);
            Assert.Equal("Only during event hours", buff.Disclaimer);
        }

        [Fact]
        public async Task DeletingEvent_CascadeDeletesBuffs()
        {
            Event ev = MakeEvent();
            ev.Buffs =
            [
                new EventBuff { EventId = ev.Id, Text = "Buff 1", Category = BuffCategory.Other },
                new EventBuff { EventId = ev.Id, Text = "Buff 2", Category = BuffCategory.Other },
            ];

            _context.Events.Add(ev);
            await _context.SaveChangesAsync();

            _context.Events.Remove(ev);
            await _context.SaveChangesAsync();

            Assert.Empty(await _context.EventBuffs.Where(b => b.EventId == ev.Id).ToListAsync());
        }

        private static Event MakeEvent(string? id = null)
        {
            return new()
            {
                Id = id ?? Guid.NewGuid().ToString(),
                Name = "Test Event",
                EventType = EventType.Event,
                Heading = "Test Heading",
                ImageUrl = "https://example.com/image.png",
                LinkUrl = "https://example.com/link",
            };
        }
    }
}
