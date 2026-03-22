using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace GoCalGo.Api.Tests.Data
{
    public class EventFlagStorageTests : IDisposable
    {
        private readonly GoCalGoDbContext _context;

        public EventFlagStorageTests()
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
        public async Task SavedEventFlag_PersistsEventId()
        {
            EventFlag flag = MakeEventFlag();
            flag.EventId = "community-day-2026-03";

            _context.EventFlags.Add(flag);
            await _context.SaveChangesAsync();

            EventFlag stored = await _context.EventFlags.FirstAsync(f => f.Id == flag.Id);
            Assert.Equal("community-day-2026-03", stored.EventId);
        }

        [Fact]
        public async Task SavedEventFlag_PersistsDeviceToken()
        {
            EventFlag flag = MakeEventFlag();
            flag.DeviceToken = "fcm-token-xyz789";

            _context.EventFlags.Add(flag);
            await _context.SaveChangesAsync();

            EventFlag stored = await _context.EventFlags.FirstAsync(f => f.Id == flag.Id);
            Assert.Equal("fcm-token-xyz789", stored.DeviceToken);
        }

        [Fact]
        public async Task SavedEventFlag_PersistsCreatedAt()
        {
            EventFlag flag = MakeEventFlag();
            flag.CreatedAt = new DateTime(2026, 3, 21, 10, 0, 0, DateTimeKind.Utc);

            _context.EventFlags.Add(flag);
            await _context.SaveChangesAsync();

            EventFlag stored = await _context.EventFlags.FirstAsync(f => f.Id == flag.Id);
            Assert.Equal(new DateTime(2026, 3, 21, 10, 0, 0, DateTimeKind.Utc), stored.CreatedAt);
        }

        [Fact]
        public async Task SavedEventFlag_CanBeDeleted()
        {
            EventFlag flag = MakeEventFlag();

            _context.EventFlags.Add(flag);
            await _context.SaveChangesAsync();

            _context.EventFlags.Remove(flag);
            await _context.SaveChangesAsync();

            Assert.Empty(await _context.EventFlags.Where(f => f.Id == flag.Id).ToListAsync());
        }

        [Fact]
        public async Task MultipleFlagsForSameEvent_CanBeSaved()
        {
            EventFlag flag1 = MakeEventFlag();
            flag1.EventId = "community-day-2026-03";
            flag1.DeviceToken = "device-1";

            EventFlag flag2 = MakeEventFlag();
            flag2.EventId = "community-day-2026-03";
            flag2.DeviceToken = "device-2";

            _context.EventFlags.AddRange(flag1, flag2);
            await _context.SaveChangesAsync();

            List<EventFlag> stored = await _context.EventFlags
                .Where(f => f.EventId == "community-day-2026-03")
                .ToListAsync();
            Assert.Equal(2, stored.Count);
        }

        [Fact]
        public async Task MultipleFlagsForSameDevice_CanBeSaved()
        {
            EventFlag flag1 = MakeEventFlag();
            flag1.EventId = "event-1";
            flag1.DeviceToken = "shared-device-token";

            EventFlag flag2 = MakeEventFlag();
            flag2.EventId = "event-2";
            flag2.DeviceToken = "shared-device-token";

            _context.EventFlags.AddRange(flag1, flag2);
            await _context.SaveChangesAsync();

            List<EventFlag> stored = await _context.EventFlags
                .Where(f => f.DeviceToken == "shared-device-token")
                .ToListAsync();
            Assert.Equal(2, stored.Count);
        }

        private static EventFlag MakeEventFlag()
        {
            return new()
            {
                EventId = Guid.NewGuid().ToString(),
                DeviceToken = Guid.NewGuid().ToString(),
                CreatedAt = DateTime.UtcNow,
            };
        }
    }
}
