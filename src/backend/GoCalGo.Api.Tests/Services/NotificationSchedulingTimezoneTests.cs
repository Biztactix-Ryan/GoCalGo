using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using GoCalGo.Api.Tests.Infrastructure.Builders;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-11:
    /// "Notification scheduling accounts for the user's local timezone"
    ///
    /// Tests that notification send times are correctly calculated for users
    /// in different timezones, including DST transitions and edge cases.
    /// </summary>
    public class NotificationSchedulingTimezoneTests
    {
        private readonly NotificationScheduler _scheduler = new();
        private static readonly TimeSpan DefaultBuffer = TimeSpan.FromMinutes(15);

        #region UTC events — same instant regardless of user timezone

        [Fact]
        public void UtcEvent_UsersInDifferentTimezones_GetSameUtcSendTime()
        {
            // A UTC event ends at the same instant everywhere.
            // Users in Tokyo and New York should receive notifications at the same UTC time.
            Event ev = new EventBuilder()
                .WithName("Global Raid Hour")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 20, 0, 0, DateTimeKind.Utc))
                .Build();

            DeviceToken tokyoDevice = MakeDevice("Asia/Tokyo");
            DeviceToken newYorkDevice = MakeDevice("America/New_York");

            ScheduledNotification tokyoResult = _scheduler.CalculateNotificationTime(ev, tokyoDevice, DefaultBuffer);
            ScheduledNotification nyResult = _scheduler.CalculateNotificationTime(ev, newYorkDevice, DefaultBuffer);

            Assert.Equal(tokyoResult.ScheduledAtUtc, nyResult.ScheduledAtUtc);
            Assert.Equal(new DateTime(2026, 3, 25, 19, 45, 0, DateTimeKind.Utc), tokyoResult.ScheduledAtUtc);
        }

        [Fact]
        public void UtcEvent_BufferSubtractedFromUtcEndTime()
        {
            Event ev = new EventBuilder()
                .WithName("Raid Hour")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 4, 1, 18, 0, 0, DateTimeKind.Utc))
                .Build();

            DeviceToken device = MakeDevice("Europe/London");

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, TimeSpan.FromMinutes(30));

            Assert.Equal(new DateTime(2026, 4, 1, 17, 30, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
        }

        #endregion

        #region Local wall-clock events — different UTC send times per timezone

        [Fact]
        public void LocalEvent_DifferentTimezones_ProduceDifferentUtcSendTimes()
        {
            // A local event ending at 5:00 PM wall-clock time means:
            // - Tokyo user: 5:00 PM JST = 08:00 UTC → notification at 07:45 UTC
            // - New York user: 5:00 PM EDT = 21:00 UTC → notification at 20:45 UTC
            Event ev = new EventBuilder()
                .WithName("Community Day")
                .WithIsUtcTime(false)
                .WithEnd(new DateTime(2026, 3, 25, 17, 0, 0, DateTimeKind.Unspecified))
                .Build();

            DeviceToken tokyoDevice = MakeDevice("Asia/Tokyo");
            DeviceToken newYorkDevice = MakeDevice("America/New_York");

            ScheduledNotification tokyoResult = _scheduler.CalculateNotificationTime(ev, tokyoDevice, DefaultBuffer);
            ScheduledNotification nyResult = _scheduler.CalculateNotificationTime(ev, newYorkDevice, DefaultBuffer);

            // Tokyo is UTC+9, New York in March (EDT) is UTC-4 → 13-hour difference
            Assert.NotEqual(tokyoResult.ScheduledAtUtc, nyResult.ScheduledAtUtc);

            // Tokyo: 17:00 JST = 08:00 UTC, minus 15 min = 07:45 UTC
            Assert.Equal(new DateTime(2026, 3, 25, 7, 45, 0, DateTimeKind.Utc), tokyoResult.ScheduledAtUtc);

            // New York: 17:00 EDT = 21:00 UTC, minus 15 min = 20:45 UTC
            Assert.Equal(new DateTime(2026, 3, 25, 20, 45, 0, DateTimeKind.Utc), nyResult.ScheduledAtUtc);
        }

        [Theory]
        [InlineData("America/Los_Angeles", -7)]  // PDT in March
        [InlineData("America/Chicago", -5)]       // CDT in March
        [InlineData("America/New_York", -4)]      // EDT in March
        [InlineData("Europe/London", 0)]           // GMT in March (before spring forward)
        [InlineData("Europe/Berlin", 1)]           // CET in March
        [InlineData("Asia/Tokyo", 9)]              // JST (no DST)
        [InlineData("Australia/Sydney", 11)]       // AEDT in March
        public void LocalEvent_VariousTimezones_AppliesCorrectUtcOffset(string timezone, int expectedOffsetHours)
        {
            // March 20, 2026 — all DST rules in their expected state
            Event ev = new EventBuilder()
                .WithName("Spotlight Hour")
                .WithIsUtcTime(false)
                .WithEnd(new DateTime(2026, 3, 20, 19, 0, 0, DateTimeKind.Unspecified))
                .Build();

            DeviceToken device = MakeDevice(timezone);

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, TimeSpan.Zero);

            // With zero buffer, scheduled time = event end in UTC
            DateTime expectedUtc = new DateTime(2026, 3, 20, 19, 0, 0, DateTimeKind.Utc)
                .AddHours(-expectedOffsetHours);
            Assert.Equal(expectedUtc, result.ScheduledAtUtc);
        }

        #endregion

        #region DST transitions — spring forward

        [Fact]
        public void LocalEvent_DuringUsSpringForward_AccountsForEdtOffset()
        {
            // US spring forward: March 8, 2026 at 2:00 AM EST → 3:00 AM EDT
            // An event ending at 3:30 PM on March 8 is in EDT (UTC-4), not EST (UTC-5)
            Event ev = new EventBuilder()
                .WithName("Post-DST Event")
                .WithIsUtcTime(false)
                .WithEnd(new DateTime(2026, 3, 8, 15, 30, 0, DateTimeKind.Unspecified))
                .Build();

            DeviceToken device = MakeDevice("America/New_York");

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            // 15:30 EDT = 19:30 UTC, minus 15 min = 19:15 UTC
            Assert.Equal(new DateTime(2026, 3, 8, 19, 15, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
        }

        [Fact]
        public void LocalEvent_DayBeforeUsSpringForward_UsesEstOffset()
        {
            // March 7, 2026 — still EST (UTC-5)
            Event ev = new EventBuilder()
                .WithName("Pre-DST Event")
                .WithIsUtcTime(false)
                .WithEnd(new DateTime(2026, 3, 7, 15, 30, 0, DateTimeKind.Unspecified))
                .Build();

            DeviceToken device = MakeDevice("America/New_York");

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            // 15:30 EST = 20:30 UTC, minus 15 min = 20:15 UTC
            Assert.Equal(new DateTime(2026, 3, 7, 20, 15, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
        }

        #endregion

        #region DST transitions — fall back

        [Fact]
        public void LocalEvent_AfterUsFallBack_AccountsForEstOffset()
        {
            // US fall back: Nov 1, 2026 at 2:00 AM EDT → 1:00 AM EST
            // An event ending at 3:00 PM on Nov 1 is in EST (UTC-5)
            Event ev = new EventBuilder()
                .WithName("Post-Fallback Event")
                .WithIsUtcTime(false)
                .WithEnd(new DateTime(2026, 11, 1, 15, 0, 0, DateTimeKind.Unspecified))
                .Build();

            DeviceToken device = MakeDevice("America/New_York");

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            // 15:00 EST = 20:00 UTC, minus 15 min = 19:45 UTC
            Assert.Equal(new DateTime(2026, 11, 1, 19, 45, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
        }

        #endregion

        #region Southern hemisphere DST

        [Fact]
        public void LocalEvent_AustraliaDstTransition_AccountsForAedtToAest()
        {
            // Australia AEDT→AEST: April 5, 2026 at 3:00 AM AEDT → 2:00 AM AEST
            // An event at 4:00 PM on April 5 is in AEST (UTC+10), not AEDT (UTC+11)
            Event ev = new EventBuilder()
                .WithName("Sydney Event")
                .WithIsUtcTime(false)
                .WithEnd(new DateTime(2026, 4, 5, 16, 0, 0, DateTimeKind.Unspecified))
                .Build();

            DeviceToken device = MakeDevice("Australia/Sydney");

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            // 16:00 AEST = 06:00 UTC, minus 15 min = 05:45 UTC
            Assert.Equal(new DateTime(2026, 4, 5, 5, 45, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
        }

        #endregion

        #region Edge cases

        [Fact]
        public void LocalEvent_NoTimezoneOnDevice_ThrowsInvalidOperation()
        {
            Event ev = new EventBuilder()
                .WithName("Local Event")
                .WithIsUtcTime(false)
                .WithEnd(new DateTime(2026, 3, 25, 17, 0, 0, DateTimeKind.Unspecified))
                .Build();

            DeviceToken device = MakeDevice(timezone: null);

            Assert.Throws<InvalidOperationException>(
                () => _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer));
        }

        [Fact]
        public void UtcEvent_NoTimezoneOnDevice_StillSchedulesSuccessfully()
        {
            // UTC events don't need the device timezone
            Event ev = new EventBuilder()
                .WithName("Global Event")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 20, 0, 0, DateTimeKind.Utc))
                .Build();

            DeviceToken device = MakeDevice(timezone: null);

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            Assert.Equal(new DateTime(2026, 3, 25, 19, 45, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
        }

        [Fact]
        public void Event_NoEndTime_ThrowsInvalidOperation()
        {
            Event ev = new EventBuilder()
                .WithName("No End Event")
                .WithIsUtcTime()
                .Build();

            DeviceToken device = MakeDevice("America/New_York");

            Assert.Throws<InvalidOperationException>(
                () => _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer));
        }

        [Fact]
        public void LocalEvent_DateBoundary_CorrectlyConvertsAcrossDays()
        {
            // An event ending at 1:00 AM local in Tokyo (UTC+9) = 4:00 PM previous day UTC
            Event ev = new EventBuilder()
                .WithName("Late Night Event")
                .WithIsUtcTime(false)
                .WithEnd(new DateTime(2026, 3, 26, 1, 0, 0, DateTimeKind.Unspecified))
                .Build();

            DeviceToken device = MakeDevice("Asia/Tokyo");

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            // 01:00 JST (Mar 26) = 16:00 UTC (Mar 25), minus 15 min = 15:45 UTC (Mar 25)
            Assert.Equal(new DateTime(2026, 3, 25, 15, 45, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
        }

        [Fact]
        public void Result_PopulatesEventMetadata()
        {
            Event ev = new EventBuilder()
                .WithId("evt-123")
                .WithName("Raid Hour")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 20, 0, 0, DateTimeKind.Utc))
                .Build();

            DeviceToken device = MakeDevice("America/New_York");
            device.Id = 42;

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            Assert.Equal("evt-123", result.EventId);
            Assert.Equal("Raid Hour", result.EventName);
            Assert.Equal(42, result.DeviceTokenId);
            Assert.Equal(DefaultBuffer, result.RemainingTime);
        }

        #endregion

        #region Helpers

        private static DeviceToken MakeDevice(string? timezone)
        {
            return new DeviceToken
            {
                Id = 1,
                Token = "test-fcm-token-" + Guid.NewGuid().ToString()[..8],
                Platform = "android",
                Timezone = timezone,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
        }

        #endregion
    }
}
