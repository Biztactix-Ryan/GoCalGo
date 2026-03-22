using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using GoCalGo.Api.Tests.Infrastructure.Builders;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies that notification lead time is configurable at the four
    /// supported values: 5 min, 15 min, 30 min, and 1 hour before event ends.
    /// Covers acceptance criterion for US-GCG-28:
    ///   "Configurable notification lead time (5 min/15 min/30 min/1 hour before event ends)"
    /// </summary>
    public class ConfigurableLeadTimeTests
    {
        private readonly NotificationScheduler _scheduler = new();

        private static readonly DateTime EventEnd =
            new(2026, 4, 1, 18, 0, 0, DateTimeKind.Utc);

        private static Event MakeEvent()
        {
            return new EventBuilder()
                .WithId("evt-lead-time")
                .WithName("Community Day")
                .WithIsUtcTime()
                .WithEnd(EventEnd)
                .Build();
        }

        private static DeviceToken MakeDevice(string timezone = "UTC")
        {
            return new()
            {
                Id = 1,
                Token = "test-token",
                Platform = "android",
                Timezone = timezone,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
        }

        [Theory]
        [InlineData(5)]
        [InlineData(15)]
        [InlineData(30)]
        [InlineData(60)]
        public void SchedulesNotification_AtCorrectLeadTime(int leadTimeMinutes)
        {
            TimeSpan buffer = TimeSpan.FromMinutes(leadTimeMinutes);
            ScheduledNotification notification = _scheduler.CalculateNotificationTime(
                MakeEvent(), MakeDevice(), buffer);

            DateTime expected = EventEnd - buffer;
            Assert.Equal(expected, notification.ScheduledAtUtc);
            Assert.Equal(buffer, notification.RemainingTime);
        }

        [Fact]
        public void FiveMinuteLead_SchedulesCorrectly()
        {
            TimeSpan buffer = TimeSpan.FromMinutes(5);
            ScheduledNotification notification = _scheduler.CalculateNotificationTime(
                MakeEvent(), MakeDevice(), buffer);

            Assert.Equal(new DateTime(2026, 4, 1, 17, 55, 0, DateTimeKind.Utc), notification.ScheduledAtUtc);
            Assert.Equal(TimeSpan.FromMinutes(5), notification.RemainingTime);
        }

        [Fact]
        public void FifteenMinuteLead_SchedulesCorrectly()
        {
            TimeSpan buffer = TimeSpan.FromMinutes(15);
            ScheduledNotification notification = _scheduler.CalculateNotificationTime(
                MakeEvent(), MakeDevice(), buffer);

            Assert.Equal(new DateTime(2026, 4, 1, 17, 45, 0, DateTimeKind.Utc), notification.ScheduledAtUtc);
            Assert.Equal(TimeSpan.FromMinutes(15), notification.RemainingTime);
        }

        [Fact]
        public void ThirtyMinuteLead_SchedulesCorrectly()
        {
            TimeSpan buffer = TimeSpan.FromMinutes(30);
            ScheduledNotification notification = _scheduler.CalculateNotificationTime(
                MakeEvent(), MakeDevice(), buffer);

            Assert.Equal(new DateTime(2026, 4, 1, 17, 30, 0, DateTimeKind.Utc), notification.ScheduledAtUtc);
            Assert.Equal(TimeSpan.FromMinutes(30), notification.RemainingTime);
        }

        [Fact]
        public void OneHourLead_SchedulesCorrectly()
        {
            TimeSpan buffer = TimeSpan.FromMinutes(60);
            ScheduledNotification notification = _scheduler.CalculateNotificationTime(
                MakeEvent(), MakeDevice(), buffer);

            Assert.Equal(new DateTime(2026, 4, 1, 17, 0, 0, DateTimeKind.Utc), notification.ScheduledAtUtc);
            Assert.Equal(TimeSpan.FromMinutes(60), notification.RemainingTime);
        }

        [Theory]
        [InlineData(5)]
        [InlineData(15)]
        [InlineData(30)]
        [InlineData(60)]
        public void LocalEvent_SchedulesAtCorrectLeadTime_InDeviceTimezone(int leadTimeMinutes)
        {
            // Event ends at 5:00 PM local time, device in America/Chicago (UTC-5 in April CDT)
            Event ev = new EventBuilder()
                .WithId("evt-local-lead")
                .WithName("Raid Hour")
                .WithEnd(new DateTime(2026, 4, 1, 17, 0, 0))
                .Build();
            DeviceToken device = MakeDevice("America/Chicago");

            TimeSpan buffer = TimeSpan.FromMinutes(leadTimeMinutes);
            ScheduledNotification notification = _scheduler.CalculateNotificationTime(ev, device, buffer);

            // 17:00 CDT = 22:00 UTC (CDT is UTC-5)
            DateTime eventEndUtc = new(2026, 4, 1, 22, 0, 0, DateTimeKind.Utc);
            DateTime expectedScheduled = eventEndUtc - buffer;

            Assert.Equal(expectedScheduled, notification.ScheduledAtUtc);
            Assert.Equal(buffer, notification.RemainingTime);
        }

        [Fact]
        public void EventFlag_DefaultLeadTime_IsFifteenMinutes()
        {
            EventFlag flag = new()
            {
                EventId = "evt-1",
                DeviceToken = "token-1",
                CreatedAt = DateTime.UtcNow,
            };

            Assert.Equal(15, flag.LeadTimeMinutes);
        }

        [Theory]
        [InlineData(5)]
        [InlineData(15)]
        [InlineData(30)]
        [InlineData(60)]
        public void EventFlag_AllowedValues_AreAccepted(int minutes)
        {
            Assert.Contains(minutes, EventFlag.AllowedLeadTimeMinutes);
        }

        [Theory]
        [InlineData(0)]
        [InlineData(1)]
        [InlineData(10)]
        [InlineData(20)]
        [InlineData(45)]
        [InlineData(120)]
        public void EventFlag_DisallowedValues_AreNotInAllowedList(int minutes)
        {
            Assert.DoesNotContain(minutes, EventFlag.AllowedLeadTimeMinutes);
        }

        [Fact]
        public void EventFlag_LeadTimeCanBeSetToEachAllowedValue()
        {
            foreach (int allowed in EventFlag.AllowedLeadTimeMinutes)
            {
                EventFlag flag = new()
                {
                    EventId = "evt-1",
                    DeviceToken = "token-1",
                    CreatedAt = DateTime.UtcNow,
                    LeadTimeMinutes = allowed,
                };

                Assert.Equal(allowed, flag.LeadTimeMinutes);
            }
        }

        [Theory]
        [InlineData(5)]
        [InlineData(15)]
        [InlineData(30)]
        [InlineData(60)]
        public void NotificationMessage_ReflectsConfiguredLeadTime(int leadTimeMinutes)
        {
            TimeSpan buffer = TimeSpan.FromMinutes(leadTimeMinutes);
            ScheduledNotification notification = _scheduler.CalculateNotificationTime(
                MakeEvent(), MakeDevice(), buffer);

            // The RemainingTime on the notification should match the configured lead time
            Assert.Equal(leadTimeMinutes, (int)notification.RemainingTime.TotalMinutes);
        }
    }
}
