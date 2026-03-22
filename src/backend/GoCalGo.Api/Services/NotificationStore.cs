using GoCalGo.Api.Data;
using GoCalGo.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace GoCalGo.Api.Services
{
    public sealed class NotificationStore(GoCalGoDbContext db) : INotificationStore
    {
        public async Task ScheduleAsync(ScheduledNotification notification)
        {
            notification.CreatedAtUtc = DateTime.UtcNow;
            db.ScheduledNotifications.Add(notification);
            await db.SaveChangesAsync();
        }

        public async Task<int> CancelByEventAndDeviceAsync(string eventId, int deviceTokenId)
        {
            return await db.ScheduledNotifications
                .Where(n => n.EventId == eventId
                         && n.DeviceTokenId == deviceTokenId
                         && n.Status == NotificationStatus.Pending)
                .ExecuteUpdateAsync(s => s.SetProperty(n => n.Status, NotificationStatus.Cancelled));
        }

        public async Task<IReadOnlyList<ScheduledNotification>> GetPendingByDeviceAsync(int deviceTokenId)
        {
            return await db.ScheduledNotifications
                .Where(n => n.DeviceTokenId == deviceTokenId && n.Status == NotificationStatus.Pending)
                .AsNoTracking()
                .ToListAsync();
        }
    }
}
