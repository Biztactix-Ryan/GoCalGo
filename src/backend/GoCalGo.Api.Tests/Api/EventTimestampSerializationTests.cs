using System.Globalization;
using System.Text.Json;
using GoCalGo.Api.Models;

namespace GoCalGo.Api.Tests.Api
{
    public class EventTimestampSerializationTests
    {
        private static readonly JsonSerializerOptions ApiJsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        };

        [Fact]
        public void Serialize_UtcTimestamp_IncludesTimezoneOffset()
        {
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 4, 11, 20, 0, 0, DateTimeKind.Utc);
            ev.End = new DateTime(2026, 4, 11, 21, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            JsonDocument doc = JsonDocument.Parse(json);
            JsonElement root = doc.RootElement;

            string start = root.GetProperty("start").GetString()!;
            string end = root.GetProperty("end").GetString()!;

            // UTC timestamps must include timezone indicator (Z or +00:00)
            Assert.Matches(@"(Z|\+00:00)$", start);
            Assert.Matches(@"(Z|\+00:00)$", end);
        }

        [Fact]
        public void Serialize_LocalTimestamp_DoesNotIncludeUtcSuffix()
        {
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 4, 11, 14, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 4, 11, 17, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            JsonDocument doc = JsonDocument.Parse(json);
            JsonElement root = doc.RootElement;

            string start = root.GetProperty("start").GetString()!;
            string end = root.GetProperty("end").GetString()!;

            // Local-time events should not have a UTC 'Z' suffix
            Assert.DoesNotMatch(@"Z$", start);
            Assert.DoesNotMatch(@"Z$", end);
        }

        [Fact]
        public void Serialize_UtcTimestamp_RoundtripsWithTimezonePreserved()
        {
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 8, 1, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.NotNull(deserialized.Start);
            Assert.Equal(DateTimeKind.Utc, deserialized.Start!.Value.Kind);
            Assert.Equal(ev.Start, deserialized.Start);
        }

        [Fact]
        public void Serialize_NullTimestamps_OmitsOrSerializesNull()
        {
            Event ev = MakeEvent();
            ev.Start = null;
            ev.End = null;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            JsonDocument doc = JsonDocument.Parse(json);
            JsonElement root = doc.RootElement;

            // Null timestamps should serialize as null, not throw
            Assert.Equal(JsonValueKind.Null, root.GetProperty("start").ValueKind);
            Assert.Equal(JsonValueKind.Null, root.GetProperty("end").ValueKind);
        }

        [Fact]
        public void Serialize_IsUtcTimeFlag_IsIncluded()
        {
            Event utcEvent = MakeEvent();
            utcEvent.IsUtcTime = true;

            Event localEvent = MakeEvent();
            localEvent.IsUtcTime = false;

            string utcJson = JsonSerializer.Serialize(utcEvent, ApiJsonOptions);
            string localJson = JsonSerializer.Serialize(localEvent, ApiJsonOptions);

            JsonDocument utcDoc = JsonDocument.Parse(utcJson);
            JsonDocument localDoc = JsonDocument.Parse(localJson);

            Assert.True(utcDoc.RootElement.GetProperty("isUtcTime").GetBoolean());
            Assert.False(localDoc.RootElement.GetProperty("isUtcTime").GetBoolean());
        }

        [Fact]
        public void Serialize_LocalTimestamp_RoundtripsWithWallClockTimePreserved()
        {
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 4, 11, 14, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 4, 11, 17, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.NotNull(deserialized.Start);
            Assert.NotNull(deserialized.End);
            Assert.False(deserialized.IsUtcTime);

            // Wall-clock time must be preserved exactly — no timezone shift.
            Assert.Equal(14, deserialized.Start!.Value.Hour);
            Assert.Equal(0, deserialized.Start.Value.Minute);
            Assert.Equal(17, deserialized.End!.Value.Hour);
            Assert.Equal(0, deserialized.End.Value.Minute);
            Assert.Equal(2026, deserialized.Start.Value.Year);
            Assert.Equal(4, deserialized.Start.Value.Month);
            Assert.Equal(11, deserialized.Start.Value.Day);
        }

        [Fact]
        public void Serialize_LocalTimestamp_MultipleEventTypes_PreserveWallClockTime()
        {
            // Community Day, Spotlight Hour, and Raid Hour all use local time.
            // The wall-clock time must survive serialization for all of them.
            (int Hour, int Minute, string Name)[] testCases =
            [
                (14, 0, "Community Day"),   // 2:00 PM
                (18, 0, "Spotlight Hour"),  // 6:00 PM
                (18, 0, "Raid Hour"),       // 6:00 PM
                (0, 0, "Midnight event"),   // midnight edge
                (23, 59, "Late night"),     // end-of-day edge
            ];

            foreach ((int hour, int minute, string _) in testCases)
            {
                Event ev = MakeEvent();
                ev.Start = new DateTime(2026, 4, 11, hour, minute, 0, DateTimeKind.Unspecified);
                ev.IsUtcTime = false;

                string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
                Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

                Assert.NotNull(deserialized);
                Assert.Equal(hour, deserialized.Start!.Value.Hour);
                Assert.Equal(minute, deserialized.Start.Value.Minute);
            }
        }

        [Fact]
        public void Serialize_FixedUtcTimestamp_DeserializesToSameInstant()
        {
            // Fixed UTC event (e.g. GO Fest) — the exact instant must survive roundtrip
            // so that any client can convert to its local timezone correctly.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 6, 7, 10, 0, 0, DateTimeKind.Utc);
            ev.End = new DateTime(2026, 6, 7, 18, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.True(deserialized.IsUtcTime);

            // The deserialized UTC instant must be identical to the original.
            Assert.Equal(DateTimeKind.Utc, deserialized.Start!.Value.Kind);
            Assert.Equal(DateTimeKind.Utc, deserialized.End!.Value.Kind);
            Assert.Equal(ev.Start, deserialized.Start);
            Assert.Equal(ev.End, deserialized.End);

            // A client converting to local must get the same result as direct conversion.
            DateTimeOffset originalStart = new(ev.Start.Value, TimeSpan.Zero);
            DateTimeOffset deserializedStart = new(deserialized.Start.Value, TimeSpan.Zero);
            Assert.Equal(originalStart.LocalDateTime, deserializedStart.LocalDateTime);
        }

        [Fact]
        public void Serialize_MultipleFixedUtcEvents_AllPreserveInstant()
        {
            // Multiple UTC events at different times of day — all must roundtrip.
            DateTime[] utcTimes =
            [
                new(2026, 6, 7, 10, 0, 0, DateTimeKind.Utc),   // GO Fest morning
                new(2026, 6, 7, 0, 0, 0, DateTimeKind.Utc),    // midnight UTC
                new(2026, 12, 31, 23, 0, 0, DateTimeKind.Utc), // year boundary
                new(2026, 3, 8, 7, 0, 0, DateTimeKind.Utc),    // near DST change
            ];

            foreach (DateTime utcTime in utcTimes)
            {
                Event ev = MakeEvent();
                ev.Start = utcTime;
                ev.IsUtcTime = true;

                string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
                Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

                Assert.NotNull(deserialized);
                Assert.Equal(DateTimeKind.Utc, deserialized.Start!.Value.Kind);
                Assert.Equal(utcTime, deserialized.Start.Value);
            }
        }

        [Fact]
        public void Serialize_UtcTimestamp_ParseableAsIso8601WithOffset()
        {
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 7, 1, 10, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            JsonDocument doc = JsonDocument.Parse(json);
            string start = doc.RootElement.GetProperty("start").GetString()!;

            // Must be parseable as a DateTimeOffset with zero offset
            DateTimeOffset parsed = DateTimeOffset.Parse(start, CultureInfo.InvariantCulture);
            Assert.Equal(TimeSpan.Zero, parsed.Offset);
            Assert.Equal(2026, parsed.Year);
            Assert.Equal(7, parsed.Month);
            Assert.Equal(1, parsed.Day);
            Assert.Equal(10, parsed.Hour);
        }

        #region DST transition edge cases

        [Fact]
        public void Serialize_UtcTimestamp_NearDstSpringForward_PreservesInstant()
        {
            // UTC time that falls in the spring-forward gap (2:00 AM EST → 3:00 AM EDT)
            // for US Eastern on March 8, 2026. The UTC instant must survive roundtrip
            // regardless of the server's timezone.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 8, 7, 0, 0, DateTimeKind.Utc); // 2:00 AM EST / 3:00 AM EDT
            ev.End = new DateTime(2026, 3, 8, 8, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(DateTimeKind.Utc, deserialized.Start!.Value.Kind);
            Assert.Equal(ev.Start, deserialized.Start);
            Assert.Equal(ev.End, deserialized.End);
        }

        [Fact]
        public void Serialize_UtcTimestamp_NearDstFallBack_PreservesInstant()
        {
            // UTC time during the fall-back ambiguous hour (1:00 AM occurs twice in EST/EDT).
            // Nov 1, 2026: 2:00 AM EDT → 1:00 AM EST.
            // UTC 5:30 AM = 1:30 AM EDT (before fall-back) and UTC 6:30 AM = 1:30 AM EST (after).
            Event evBefore = MakeEvent();
            evBefore.Start = new DateTime(2026, 11, 1, 5, 30, 0, DateTimeKind.Utc);
            evBefore.IsUtcTime = true;

            Event evAfter = MakeEvent();
            evAfter.Start = new DateTime(2026, 11, 1, 6, 30, 0, DateTimeKind.Utc);
            evAfter.IsUtcTime = true;

            string jsonBefore = JsonSerializer.Serialize(evBefore, ApiJsonOptions);
            string jsonAfter = JsonSerializer.Serialize(evAfter, ApiJsonOptions);

            Event? deserBefore = JsonSerializer.Deserialize<Event>(jsonBefore, ApiJsonOptions);
            Event? deserAfter = JsonSerializer.Deserialize<Event>(jsonAfter, ApiJsonOptions);

            Assert.NotNull(deserBefore);
            Assert.NotNull(deserAfter);
            // Both instants must survive roundtrip as distinct UTC moments.
            Assert.Equal(evBefore.Start, deserBefore.Start);
            Assert.Equal(evAfter.Start, deserAfter.Start);
            Assert.NotEqual(deserBefore.Start, deserAfter.Start);
        }

        [Fact]
        public void Serialize_LocalTimestamp_OnDstDay_PreservesWallClockTime()
        {
            // Local-time events (Community Day etc.) on a DST transition day
            // must preserve the wall-clock time regardless of DST.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 8, 14, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 3, 8, 17, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(14, deserialized.Start!.Value.Hour);
            Assert.Equal(17, deserialized.End!.Value.Hour);
            Assert.Equal(8, deserialized.Start.Value.Day);
            Assert.False(deserialized.IsUtcTime);
        }

        [Fact]
        public void Serialize_LocalTimestamp_MultiDaySpanningDst_PreservesWallClockTime()
        {
            // Multi-day event crossing DST boundary — wall-clock times on both
            // sides of the transition must be preserved.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 7, 10, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 3, 10, 20, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(10, deserialized.Start!.Value.Hour);
            Assert.Equal(7, deserialized.Start.Value.Day);
            Assert.Equal(20, deserialized.End!.Value.Hour);
            Assert.Equal(10, deserialized.End.Value.Day);
        }

        #endregion

        #region Date boundary crossing edge cases

        [Fact]
        public void Serialize_LocalTimestamp_AtExactMidnight_PreservesDateAndHour()
        {
            // Midnight boundary — hour 0 must not drift to hour 24 of previous day.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 4, 1, 0, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 4, 1, 8, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(0, deserialized.Start!.Value.Hour);
            Assert.Equal(1, deserialized.Start.Value.Day);
            Assert.Equal(4, deserialized.Start.Value.Month);
        }

        [Fact]
        public void Serialize_LocalTimestamp_CrossingMidnight_PreservesBothDays()
        {
            // Event from 10 PM to 2 AM next day — dates must be preserved.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 21, 22, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 3, 22, 2, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(21, deserialized.Start!.Value.Day);
            Assert.Equal(22, deserialized.Start.Value.Hour);
            Assert.Equal(22, deserialized.End!.Value.Day);
            Assert.Equal(2, deserialized.End.Value.Hour);
        }

        [Fact]
        public void Serialize_LocalTimestamp_CrossingMonthBoundary_PreservesMonths()
        {
            // Event spanning March 31 to April 1.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 31, 10, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 4, 1, 20, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(3, deserialized.Start!.Value.Month);
            Assert.Equal(31, deserialized.Start.Value.Day);
            Assert.Equal(4, deserialized.End!.Value.Month);
            Assert.Equal(1, deserialized.End.Value.Day);
        }

        [Fact]
        public void Serialize_UtcTimestamp_CrossingYearBoundary_RoundtripsCorrectly()
        {
            // Dec 31 23:00 UTC to Jan 1 01:00 UTC — year boundary.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 12, 31, 23, 0, 0, DateTimeKind.Utc);
            ev.End = new DateTime(2027, 1, 1, 1, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(2026, deserialized.Start!.Value.Year);
            Assert.Equal(12, deserialized.Start.Value.Month);
            Assert.Equal(31, deserialized.Start.Value.Day);
            Assert.Equal(2027, deserialized.End!.Value.Year);
            Assert.Equal(1, deserialized.End.Value.Month);
            Assert.Equal(1, deserialized.End.Value.Day);
        }

        [Fact]
        public void Serialize_LocalTimestamp_LeapYearFeb29_PreservesDate()
        {
            // Leap year date — Feb 29, 2028 must survive roundtrip.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2028, 2, 29, 14, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2028, 3, 1, 6, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(2028, deserialized.Start!.Value.Year);
            Assert.Equal(2, deserialized.Start.Value.Month);
            Assert.Equal(29, deserialized.Start.Value.Day);
            Assert.Equal(14, deserialized.Start.Value.Hour);
            Assert.Equal(3, deserialized.End!.Value.Month);
            Assert.Equal(1, deserialized.End.Value.Day);
        }

        [Fact]
        public void Serialize_LocalTimestamp_At2359_PreservesWithoutRollover()
        {
            // 23:59 must not roll to 00:00 of next day.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 6, 15, 23, 59, 59, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(15, deserialized.Start!.Value.Day);
            Assert.Equal(23, deserialized.Start.Value.Hour);
            Assert.Equal(59, deserialized.Start.Value.Minute);
            Assert.Equal(59, deserialized.Start.Value.Second);
        }

        #endregion

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
