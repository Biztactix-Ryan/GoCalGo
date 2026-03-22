using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace GoCalGo.Api.Tests.Data
{
    public class DeviceTokenStorageTests : IDisposable
    {
        private readonly GoCalGoDbContext _context;

        public DeviceTokenStorageTests()
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
        public async Task SavedDeviceToken_PersistsToken()
        {
            DeviceToken token = MakeDeviceToken();
            token.Token = "fcm-token-abc123";

            _context.DeviceTokens.Add(token);
            await _context.SaveChangesAsync();

            DeviceToken stored = await _context.DeviceTokens.FirstAsync(t => t.Id == token.Id);
            Assert.Equal("fcm-token-abc123", stored.Token);
        }

        [Fact]
        public async Task SavedDeviceToken_PersistsPlatform()
        {
            DeviceToken token = MakeDeviceToken();
            token.Platform = "ios";

            _context.DeviceTokens.Add(token);
            await _context.SaveChangesAsync();

            DeviceToken stored = await _context.DeviceTokens.FirstAsync(t => t.Id == token.Id);
            Assert.Equal("ios", stored.Platform);
        }

        [Fact]
        public async Task SavedDeviceToken_PersistsTimestamps()
        {
            DeviceToken token = MakeDeviceToken();
            token.CreatedAt = new DateTime(2026, 3, 20, 10, 0, 0, DateTimeKind.Utc);
            token.UpdatedAt = new DateTime(2026, 3, 21, 12, 0, 0, DateTimeKind.Utc);

            _context.DeviceTokens.Add(token);
            await _context.SaveChangesAsync();

            DeviceToken stored = await _context.DeviceTokens.FirstAsync(t => t.Id == token.Id);
            Assert.Equal(new DateTime(2026, 3, 20, 10, 0, 0, DateTimeKind.Utc), stored.CreatedAt);
            Assert.Equal(new DateTime(2026, 3, 21, 12, 0, 0, DateTimeKind.Utc), stored.UpdatedAt);
        }

        [Fact]
        public async Task SavedDeviceToken_PersistsAllFields()
        {
            DeviceToken token = new()
            {
                Token = "full-token-xyz789",
                Platform = "android",
                CreatedAt = new DateTime(2026, 1, 15, 8, 30, 0, DateTimeKind.Utc),
                UpdatedAt = new DateTime(2026, 3, 21, 14, 0, 0, DateTimeKind.Utc),
            };

            _context.DeviceTokens.Add(token);
            await _context.SaveChangesAsync();

            DeviceToken stored = await _context.DeviceTokens.FirstAsync(t => t.Token == "full-token-xyz789");
            Assert.Equal("full-token-xyz789", stored.Token);
            Assert.Equal("android", stored.Platform);
            Assert.Equal(new DateTime(2026, 1, 15, 8, 30, 0, DateTimeKind.Utc), stored.CreatedAt);
            Assert.Equal(new DateTime(2026, 3, 21, 14, 0, 0, DateTimeKind.Utc), stored.UpdatedAt);
        }

        [Fact]
        public async Task SavedDeviceToken_CanBeDeleted()
        {
            DeviceToken token = MakeDeviceToken();

            _context.DeviceTokens.Add(token);
            await _context.SaveChangesAsync();

            _context.DeviceTokens.Remove(token);
            await _context.SaveChangesAsync();

            Assert.Empty(await _context.DeviceTokens.Where(t => t.Id == token.Id).ToListAsync());
        }

        [Fact]
        public async Task SavedDeviceToken_CanBeUpdated()
        {
            DeviceToken token = MakeDeviceToken();
            token.Token = "original-token";

            _context.DeviceTokens.Add(token);
            await _context.SaveChangesAsync();

            token.Token = "refreshed-token";
            token.UpdatedAt = new DateTime(2026, 3, 21, 16, 0, 0, DateTimeKind.Utc);
            await _context.SaveChangesAsync();

            DeviceToken stored = await _context.DeviceTokens.FirstAsync(t => t.Id == token.Id);
            Assert.Equal("refreshed-token", stored.Token);
            Assert.Equal(new DateTime(2026, 3, 21, 16, 0, 0, DateTimeKind.Utc), stored.UpdatedAt);
        }

        [Fact]
        public async Task MultipleDeviceTokens_CanBeSavedAndQueried()
        {
            DeviceToken token1 = MakeDeviceToken();
            token1.Token = "token-device-1";
            token1.Platform = "ios";

            DeviceToken token2 = MakeDeviceToken();
            token2.Token = "token-device-2";
            token2.Platform = "android";

            _context.DeviceTokens.AddRange(token1, token2);
            await _context.SaveChangesAsync();

            List<DeviceToken> stored = await _context.DeviceTokens.ToListAsync();
            Assert.Equal(2, stored.Count);
            Assert.Contains(stored, t => t.Token == "token-device-1" && t.Platform == "ios");
            Assert.Contains(stored, t => t.Token == "token-device-2" && t.Platform == "android");
        }

        private static DeviceToken MakeDeviceToken()
        {
            return new()
            {
                Token = Guid.NewGuid().ToString(),
                Platform = "android",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
        }
    }
}
