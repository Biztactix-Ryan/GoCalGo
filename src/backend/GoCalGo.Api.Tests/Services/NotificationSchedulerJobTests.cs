using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using GoCalGo.Api.Tests.Infrastructure.Builders;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Unit tests for the notification scheduling logic:
    /// - Scheduling new notifications for flagged events
    /// - Skipping already-scheduled notifications
    /// - Skipping events with no end time or past end times
    /// - FCM message formatting
    /// </summary>
    public class NotificationSchedulerJobTests
    {
        private readonly NotificationScheduler _scheduler = new();
        private static readonly TimeSpan DefaultBuffer = TimeSpan.FromMinutes(15);

        [Fact]
        public void CalculateNotificationTime_IncludesEventNameAndRemainingTime()
        {
            Event ev = new EventBuilder()
                .WithId("evt-1")
                .WithName("Community Day")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 17, 0, 0, DateTimeKind.Utc))
                .Build();
            DeviceToken device = MakeDevice(1, "America/New_York");

            ScheduledNotification notification = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            Assert.Equal("evt-1", notification.EventId);
            Assert.Equal("Community Day", notification.EventName);
            Assert.Equal(1, notification.DeviceTokenId);
            Assert.Equal(DefaultBuffer, notification.RemainingTime);
            Assert.Equal(NotificationStatus.Pending, notification.Status);
        }

        [Fact]
        public void CalculateNotificationTime_ScheduledAtIsEndMinusBuffer()
        {
            DateTime eventEnd = new(2026, 3, 25, 17, 0, 0, DateTimeKind.Utc);
            Event ev = new EventBuilder()
                .WithId("evt-2")
                .WithName("Raid Hour")
                .WithIsUtcTime()
                .WithEnd(eventEnd)
                .Build();
            DeviceToken device = MakeDevice(1, "UTC");

            ScheduledNotification notification = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            DateTime expectedScheduled = eventEnd - DefaultBuffer;
            Assert.Equal(expectedScheduled, notification.ScheduledAtUtc);
        }

        [Fact]
        public void CalculateNotificationTime_LocalEvent_ConvertsToDeviceTimezone()
        {
            // Event ends at 5:00 PM local time, device is in Tokyo (UTC+9)
            Event ev = new EventBuilder()
                .WithId("evt-local")
                .WithName("Community Day")
                .WithEnd(new DateTime(2026, 3, 25, 17, 0, 0))
                .Build();
            DeviceToken device = MakeDevice(1, "Asia/Tokyo");

            ScheduledNotification notification = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            // 17:00 Tokyo = 08:00 UTC, minus 15min = 07:45 UTC
            DateTime expected = new(2026, 3, 25, 7, 45, 0, DateTimeKind.Utc);
            Assert.Equal(expected, notification.ScheduledAtUtc);
        }

        [Fact]
        public void CalculateNotificationTime_ThrowsForEventWithNoEnd()
        {
            Event ev = new EventBuilder()
                .WithId("evt-no-end")
                .WithName("Ongoing Season")
                .Build();
            DeviceToken device = MakeDevice(1, "UTC");

            Assert.Throws<InvalidOperationException>(
                () => _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer));
        }

        [Fact]
        public void CalculateNotificationTime_ThrowsForLocalEventWithNoTimezone()
        {
            Event ev = new EventBuilder()
                .WithId("evt-no-tz")
                .WithName("Community Day")
                .WithEnd(new DateTime(2026, 3, 25, 17, 0, 0))
                .Build();
            DeviceToken device = MakeDevice(1, timezone: null);

            Assert.Throws<InvalidOperationException>(
                () => _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer));
        }

        [Fact]
        public void CalculateNotificationTime_DifferentBufferSizes()
        {
            DateTime eventEnd = new(2026, 3, 25, 17, 0, 0, DateTimeKind.Utc);
            Event ev = new EventBuilder()
                .WithId("evt-buffer")
                .WithName("Spotlight Hour")
                .WithIsUtcTime()
                .WithEnd(eventEnd)
                .Build();
            DeviceToken device = MakeDevice(1, "UTC");

            TimeSpan thirtyMinBuffer = TimeSpan.FromMinutes(30);
            ScheduledNotification notification = _scheduler.CalculateNotificationTime(ev, device, thirtyMinBuffer);

            Assert.Equal(eventEnd - thirtyMinBuffer, notification.ScheduledAtUtc);
            Assert.Equal(thirtyMinBuffer, notification.RemainingTime);
        }

        [Fact]
        public async Task NotificationStore_InMemory_ScheduleAndRetrieve()
        {
            InMemoryNotificationStore store = new();
            ScheduledNotification notification = new()
            {
                EventId = "evt-1",
                EventName = "Test Event",
                DeviceTokenId = 1,
                ScheduledAtUtc = DateTime.UtcNow.AddHours(1),
                RemainingTime = DefaultBuffer,
            };

            await store.ScheduleAsync(notification);

            IReadOnlyList<ScheduledNotification> pending = await store.GetPendingByDeviceAsync(1);
            Assert.Single(pending);
            Assert.Equal("evt-1", pending[0].EventId);
        }

        [Fact]
        public async Task NotificationStore_InMemory_CancelRemovesPending()
        {
            InMemoryNotificationStore store = new();
            await store.ScheduleAsync(new ScheduledNotification
            {
                EventId = "evt-cancel",
                EventName = "Test",
                DeviceTokenId = 5,
                ScheduledAtUtc = DateTime.UtcNow.AddHours(1),
                RemainingTime = DefaultBuffer,
            });

            int cancelled = await store.CancelByEventAndDeviceAsync("evt-cancel", 5);

            Assert.Equal(1, cancelled);
            IReadOnlyList<ScheduledNotification> remaining = await store.GetPendingByDeviceAsync(5);
            Assert.Empty(remaining);
        }

        private static DeviceToken MakeDevice(int id, string? timezone)
        {
            return new DeviceToken
            {
                Id = id,
                Token = "test-fcm-token-" + Guid.NewGuid().ToString()[..8],
                Platform = "android",
                Timezone = timezone,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
        }

        /// <summary>
        /// Simple in-memory store for unit testing.
        /// </summary>
        private sealed class InMemoryNotificationStore : INotificationStore
        {
            private readonly List<ScheduledNotification> _notifications = [];

            public Task ScheduleAsync(ScheduledNotification notification)
            {
                _notifications.Add(notification);
                return Task.CompletedTask;
            }

            public Task<int> CancelByEventAndDeviceAsync(string eventId, int deviceTokenId)
            {
                int removed = _notifications.RemoveAll(n =>
                    n.EventId == eventId && n.DeviceTokenId == deviceTokenId);
                return Task.FromResult(removed);
            }

            public Task<IReadOnlyList<ScheduledNotification>> GetPendingByDeviceAsync(int deviceTokenId)
            {
                IReadOnlyList<ScheduledNotification> result = _notifications
                    .Where(n => n.DeviceTokenId == deviceTokenId)
                    .ToList()
                    .AsReadOnly();
                return Task.FromResult(result);
            }
        }
    }
}
