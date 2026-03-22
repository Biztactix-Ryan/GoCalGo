using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using GoCalGo.Api.Tests.Infrastructure.Builders;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-11:
    /// "Unflagging an event cancels the scheduled notification"
    ///
    /// Tests that when a user unflags an event, any previously scheduled
    /// notification for that event+device combination is removed from the store.
    /// </summary>
    public class UnflagCancelsNotificationTests
    {
        private readonly NotificationScheduler _scheduler = new();
        private static readonly TimeSpan DefaultBuffer = TimeSpan.FromMinutes(15);

        #region Core cancellation behaviour

        [Fact]
        public async Task Unflag_RemovesScheduledNotification()
        {
            // Arrange — schedule a notification for a flagged event
            INotificationStore store = new InMemoryNotificationStore();
            Event ev = new EventBuilder()
                .WithId("evt-unflag-1")
                .WithName("Community Day")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 17, 0, 0, DateTimeKind.Utc))
                .Build();
            DeviceToken device = MakeDevice(id: 1, timezone: "America/New_York");

            ScheduledNotification notification = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);
            await store.ScheduleAsync(notification);

            // Sanity check — notification exists
            IReadOnlyList<ScheduledNotification> before = await store.GetPendingByDeviceAsync(device.Id);
            Assert.Single(before);

            // Act — unflag the event (cancel its notification)
            int cancelled = await store.CancelByEventAndDeviceAsync(ev.Id, device.Id);

            // Assert — notification is gone
            Assert.Equal(1, cancelled);
            IReadOnlyList<ScheduledNotification> after = await store.GetPendingByDeviceAsync(device.Id);
            Assert.Empty(after);
        }

        [Fact]
        public async Task Unflag_OnlyRemovesNotificationForSpecificEvent()
        {
            // Arrange — schedule notifications for two different events
            INotificationStore store = new InMemoryNotificationStore();
            DeviceToken device = MakeDevice(id: 1, timezone: "Europe/Berlin");

            Event event1 = new EventBuilder()
                .WithId("evt-keep")
                .WithName("Raid Hour")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 19, 0, 0, DateTimeKind.Utc))
                .Build();

            Event event2 = new EventBuilder()
                .WithId("evt-cancel")
                .WithName("Spotlight Hour")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 20, 0, 0, DateTimeKind.Utc))
                .Build();

            await store.ScheduleAsync(_scheduler.CalculateNotificationTime(event1, device, DefaultBuffer));
            await store.ScheduleAsync(_scheduler.CalculateNotificationTime(event2, device, DefaultBuffer));

            // Act — unflag only event2
            await store.CancelByEventAndDeviceAsync("evt-cancel", device.Id);

            // Assert — event1's notification survives
            IReadOnlyList<ScheduledNotification> remaining = await store.GetPendingByDeviceAsync(device.Id);
            Assert.Single(remaining);
            Assert.Equal("evt-keep", remaining[0].EventId);
        }

        [Fact]
        public async Task Unflag_OnlyRemovesNotificationForSpecificDevice()
        {
            // Arrange — same event flagged on two devices
            INotificationStore store = new InMemoryNotificationStore();
            Event ev = new EventBuilder()
                .WithId("evt-shared")
                .WithName("Community Day")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 17, 0, 0, DateTimeKind.Utc))
                .Build();

            DeviceToken device1 = MakeDevice(id: 10, timezone: "Asia/Tokyo");
            DeviceToken device2 = MakeDevice(id: 20, timezone: "America/Chicago");

            await store.ScheduleAsync(_scheduler.CalculateNotificationTime(ev, device1, DefaultBuffer));
            await store.ScheduleAsync(_scheduler.CalculateNotificationTime(ev, device2, DefaultBuffer));

            // Act — unflag on device1 only
            await store.CancelByEventAndDeviceAsync("evt-shared", device1.Id);

            // Assert — device2's notification is still pending
            IReadOnlyList<ScheduledNotification> device1Pending = await store.GetPendingByDeviceAsync(device1.Id);
            IReadOnlyList<ScheduledNotification> device2Pending = await store.GetPendingByDeviceAsync(device2.Id);
            Assert.Empty(device1Pending);
            Assert.Single(device2Pending);
        }

        #endregion

        #region Edge cases

        [Fact]
        public async Task Unflag_EventWithNoNotification_ReturnsZeroCancelled()
        {
            // Unflagging an event that was never flagged (or already cancelled) should be safe
            INotificationStore store = new InMemoryNotificationStore();

            int cancelled = await store.CancelByEventAndDeviceAsync("evt-never-flagged", 99);

            Assert.Equal(0, cancelled);
        }

        [Fact]
        public async Task Unflag_ThenReflag_CanScheduleNewNotification()
        {
            // Unflagging and reflagging should allow a fresh notification to be scheduled
            INotificationStore store = new InMemoryNotificationStore();
            Event ev = new EventBuilder()
                .WithId("evt-toggle")
                .WithName("Raid Hour")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 19, 0, 0, DateTimeKind.Utc))
                .Build();
            DeviceToken device = MakeDevice(id: 1, timezone: "America/New_York");

            // Flag → schedule
            ScheduledNotification notification = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);
            await store.ScheduleAsync(notification);

            // Unflag → cancel
            await store.CancelByEventAndDeviceAsync(ev.Id, device.Id);
            IReadOnlyList<ScheduledNotification> afterCancel = await store.GetPendingByDeviceAsync(device.Id);
            Assert.Empty(afterCancel);

            // Reflag → schedule again
            ScheduledNotification rescheduled = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);
            await store.ScheduleAsync(rescheduled);

            IReadOnlyList<ScheduledNotification> afterReflag = await store.GetPendingByDeviceAsync(device.Id);
            Assert.Single(afterReflag);
            Assert.Equal(ev.Id, afterReflag[0].EventId);
        }

        [Fact]
        public async Task Unflag_DoubleCancelIsIdempotent()
        {
            // Cancelling the same notification twice should not error
            INotificationStore store = new InMemoryNotificationStore();
            Event ev = new EventBuilder()
                .WithId("evt-double")
                .WithName("Go Fest")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 6, 15, 20, 0, 0, DateTimeKind.Utc))
                .Build();
            DeviceToken device = MakeDevice(id: 1, timezone: "America/New_York");

            await store.ScheduleAsync(_scheduler.CalculateNotificationTime(ev, device, DefaultBuffer));

            int firstCancel = await store.CancelByEventAndDeviceAsync(ev.Id, device.Id);
            int secondCancel = await store.CancelByEventAndDeviceAsync(ev.Id, device.Id);

            Assert.Equal(1, firstCancel);
            Assert.Equal(0, secondCancel);
        }

        #endregion

        #region Helpers

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

        #endregion

        #region In-memory test double

        /// <summary>
        /// Minimal in-memory implementation of <see cref="INotificationStore"/> for
        /// testing cancellation semantics without a database.
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

        #endregion
    }
}
