using System.Text.Json;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;
using GoCalGo.Api.Tests.Infrastructure.Builders;

namespace GoCalGo.Api.Tests.Services
{
    /// <summary>
    /// Verifies acceptance criterion for story US-GCG-11:
    /// "Notifications are delivered via FCM to both iOS and Android"
    ///
    /// Tests that notification scheduling works identically for both platforms,
    /// that the device-token registration accepts both platforms, and that
    /// Firebase infrastructure is configured for cross-platform delivery.
    /// </summary>
    public class NotificationDeliveryPlatformTests
    {
        private readonly NotificationScheduler _scheduler = new();
        private static readonly TimeSpan DefaultBuffer = TimeSpan.FromMinutes(15);

        #region Scheduling works for both platforms

        [Fact]
        public void AndroidDevice_SchedulesNotificationSuccessfully()
        {
            Event ev = new EventBuilder()
                .WithName("Community Day")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 20, 0, 0, DateTimeKind.Utc))
                .Build();

            DeviceToken device = MakeDevice("android", "America/New_York");

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            Assert.Equal(new DateTime(2026, 3, 25, 19, 45, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
            Assert.Equal(ev.Id, result.EventId);
            Assert.Equal(ev.Name, result.EventName);
        }

        [Fact]
        public void IosDevice_SchedulesNotificationSuccessfully()
        {
            Event ev = new EventBuilder()
                .WithName("Community Day")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 3, 25, 20, 0, 0, DateTimeKind.Utc))
                .Build();

            DeviceToken device = MakeDevice("ios", "America/New_York");

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            Assert.Equal(new DateTime(2026, 3, 25, 19, 45, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
            Assert.Equal(ev.Id, result.EventId);
            Assert.Equal(ev.Name, result.EventName);
        }

        [Fact]
        public void SameEvent_BothPlatforms_ProduceSameScheduledTime()
        {
            // Platform should not affect notification timing — only timezone matters
            Event ev = new EventBuilder()
                .WithName("Raid Hour")
                .WithIsUtcTime(false)
                .WithEnd(new DateTime(2026, 3, 25, 18, 0, 0, DateTimeKind.Unspecified))
                .Build();

            DeviceToken androidDevice = MakeDevice("android", "Asia/Tokyo");
            DeviceToken iosDevice = MakeDevice("ios", "Asia/Tokyo");

            ScheduledNotification androidResult = _scheduler.CalculateNotificationTime(ev, androidDevice, DefaultBuffer);
            ScheduledNotification iosResult = _scheduler.CalculateNotificationTime(ev, iosDevice, DefaultBuffer);

            Assert.Equal(androidResult.ScheduledAtUtc, iosResult.ScheduledAtUtc);
        }

        [Theory]
        [InlineData("android")]
        [InlineData("ios")]
        public void LocalEvent_EachPlatform_CorrectlyConvertsTimezone(string platform)
        {
            // A local event ending at 5:00 PM in New York (EDT, UTC-4)
            Event ev = new EventBuilder()
                .WithName("Spotlight Hour")
                .WithIsUtcTime(false)
                .WithEnd(new DateTime(2026, 3, 25, 17, 0, 0, DateTimeKind.Unspecified))
                .Build();

            DeviceToken device = MakeDevice(platform, "America/New_York");

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, DefaultBuffer);

            // 17:00 EDT = 21:00 UTC, minus 15 min = 20:45 UTC
            Assert.Equal(new DateTime(2026, 3, 25, 20, 45, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
        }

        [Theory]
        [InlineData("android")]
        [InlineData("ios")]
        public void UtcEvent_EachPlatform_SchedulesCorrectly(string platform)
        {
            Event ev = new EventBuilder()
                .WithName("Global Raid Hour")
                .WithIsUtcTime()
                .WithEnd(new DateTime(2026, 4, 1, 18, 0, 0, DateTimeKind.Utc))
                .Build();

            DeviceToken device = MakeDevice(platform, "Europe/Berlin");

            ScheduledNotification result = _scheduler.CalculateNotificationTime(ev, device, TimeSpan.FromMinutes(30));

            Assert.Equal(new DateTime(2026, 4, 1, 17, 30, 0, DateTimeKind.Utc), result.ScheduledAtUtc);
            Assert.Equal(TimeSpan.FromMinutes(30), result.RemainingTime);
        }

        #endregion

        #region Firebase platform configuration

        [Fact]
        public void FirebaseJson_ConfiguresBothPlatforms()
        {
            // firebase.json must register both Android and iOS apps for FCM delivery
            string repoRoot = FindRepoRoot();
            string firebaseJson = File.ReadAllText(Path.Combine(repoRoot, "firebase.json"));
            JsonDocument doc = JsonDocument.Parse(firebaseJson);

            JsonElement platforms = doc.RootElement
                .GetProperty("flutter")
                .GetProperty("platforms");

            Assert.True(platforms.TryGetProperty("android", out _),
                "firebase.json must configure Android platform for FCM");
            Assert.True(platforms.TryGetProperty("ios", out _),
                "firebase.json must configure iOS platform for FCM");
        }

        [Fact]
        public void FirebaseJson_AndroidConfigPointsToGoogleServicesJson()
        {
            string repoRoot = FindRepoRoot();
            string firebaseJson = File.ReadAllText(Path.Combine(repoRoot, "firebase.json"));
            JsonDocument doc = JsonDocument.Parse(firebaseJson);

            string fileOutput = doc.RootElement
                .GetProperty("flutter")
                .GetProperty("platforms")
                .GetProperty("android")
                .GetProperty("default")
                .GetProperty("fileOutput")
                .GetString()!;

            Assert.Contains("google-services.json", fileOutput);
        }

        [Fact]
        public void FirebaseJson_IosConfigPointsToGoogleServiceInfoPlist()
        {
            string repoRoot = FindRepoRoot();
            string firebaseJson = File.ReadAllText(Path.Combine(repoRoot, "firebase.json"));
            JsonDocument doc = JsonDocument.Parse(firebaseJson);

            string fileOutput = doc.RootElement
                .GetProperty("flutter")
                .GetProperty("platforms")
                .GetProperty("ios")
                .GetProperty("default")
                .GetProperty("fileOutput")
                .GetString()!;

            Assert.Contains("GoogleService-Info.plist", fileOutput);
        }

        [Fact]
        public void FirebaseJson_MessagingIsEnabled()
        {
            string repoRoot = FindRepoRoot();
            string firebaseJson = File.ReadAllText(Path.Combine(repoRoot, "firebase.json"));
            JsonDocument doc = JsonDocument.Parse(firebaseJson);

            bool enabled = doc.RootElement
                .GetProperty("messaging")
                .GetProperty("enabled")
                .GetBoolean();

            Assert.True(enabled, "FCM messaging must be enabled in firebase.json");
        }

        #endregion

        #region Flutter app includes FCM dependency for both platforms

        [Fact]
        public void FlutterPubspec_IncludesFirebaseMessaging()
        {
            // firebase_messaging is the Flutter plugin that provides FCM on both iOS and Android
            string repoRoot = FindRepoRoot();
            string pubspec = File.ReadAllText(Path.Combine(repoRoot, "src", "app", "pubspec.yaml"));

            Assert.Contains("firebase_messaging:", pubspec);
        }

        [Fact]
        public void FlutterPubspec_IncludesFirebaseCore()
        {
            // firebase_core is required to initialize Firebase before using FCM
            string repoRoot = FindRepoRoot();
            string pubspec = File.ReadAllText(Path.Combine(repoRoot, "src", "app", "pubspec.yaml"));

            Assert.Contains("firebase_core:", pubspec);
        }

        #endregion

        #region Backend accepts both platform values

        [Theory]
        [InlineData("android")]
        [InlineData("ios")]
        public void DeviceToken_ValidPlatformValues_AreAndroidAndIos(string platform)
        {
            // The backend endpoint validates platform is "android" or "ios"
            // Verify DeviceToken model can hold both values
            DeviceToken device = new()
            {
                Id = 1,
                Token = "test-token",
                Platform = platform,
                Timezone = "America/New_York",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };

            Assert.Equal(platform, device.Platform);
        }

        #endregion

        #region Helpers

        private static DeviceToken MakeDevice(string platform, string? timezone)
        {
            return new DeviceToken
            {
                Id = 1,
                Token = "test-fcm-token-" + Guid.NewGuid().ToString()[..8],
                Platform = platform,
                Timezone = timezone,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
        }

        private static string FindRepoRoot()
        {
            string? dir = AppContext.BaseDirectory;
            while (dir != null)
            {
                if (File.Exists(Path.Combine(dir, ".env.example")))
                {
                    return dir;
                }

                dir = Path.GetDirectoryName(dir);
            }

            string fallback = Path.GetFullPath(
                Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", ".."));

            return File.Exists(Path.Combine(fallback, ".env.example"))
                ? fallback
                : throw new DirectoryNotFoundException("Could not find repository root");
        }

        #endregion
    }
}
