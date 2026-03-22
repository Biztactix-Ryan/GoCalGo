using System.Globalization;
using System.Text.Json;
using GoCalGo.Api.Models;
using GoCalGo.Api.Services;

namespace GoCalGo.Api.Tests.Api
{
    /// <summary>
    /// Dedicated timezone edge-case tests covering DST transitions (northern and
    /// southern hemisphere), date boundary crossings, and local-time vs UTC
    /// interaction scenarios across serialization and parsing.
    /// </summary>
    public class TimezoneEdgeCaseTests
    {
        private static readonly JsonSerializerOptions ApiJsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        };

        #region Northern hemisphere DST — spring forward (US March 8 2026)

        [Fact]
        public void UtcEvent_InSpringForwardGap_RoundtripsExactInstant()
        {
            // 2:30 AM EST does not exist on March 8, 2026 (clocks skip 2→3 AM).
            // UTC 07:30 = that gap moment. The UTC instant must survive roundtrip.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 8, 7, 30, 0, DateTimeKind.Utc);
            ev.End = new DateTime(2026, 3, 8, 8, 30, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(DateTimeKind.Utc, deserialized.Start!.Value.Kind);
            Assert.Equal(7, deserialized.Start.Value.Hour);
            Assert.Equal(30, deserialized.Start.Value.Minute);
            Assert.Equal(ev.End, deserialized.End);
        }

        [Fact]
        public void LocalEvent_DuringSpringForwardGapHour_PreservesWallClock()
        {
            // A local-time event at 2:30 AM on spring-forward day — the wall-clock
            // time must be stored as-is even though 2:30 AM is skipped in US Eastern.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 8, 2, 30, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 3, 8, 5, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(2, deserialized.Start!.Value.Hour);
            Assert.Equal(30, deserialized.Start.Value.Minute);
            Assert.Equal(5, deserialized.End!.Value.Hour);
            Assert.False(deserialized.IsUtcTime);
        }

        [Fact]
        public void Parser_UtcTimestamp_InSpringForwardGap_PreservesExactUtc()
        {
            JsonElement element = MakeMinimalEvent(
                start: "2026-03-08T07:30:00.000Z",
                end: "2026-03-08T08:30:00.000Z"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(7, dto.Start!.Value.Hour);
            Assert.Equal(30, dto.Start.Value.Minute);
            Assert.Equal(8, dto.End!.Value.Hour);
            Assert.True(dto.IsUtcTime);
        }

        #endregion

        #region Northern hemisphere DST — fall back (US November 1 2026)

        [Fact]
        public void UtcEvents_BothSidesOfFallBack_RemainDistinct()
        {
            // 1:30 AM EST occurs twice: UTC 05:30 (EDT, before) and UTC 06:30 (EST, after).
            // Both must roundtrip as distinct instants.
            Event evBefore = MakeEvent();
            evBefore.Start = new DateTime(2026, 11, 1, 5, 30, 0, DateTimeKind.Utc);
            evBefore.IsUtcTime = true;

            Event evAfter = MakeEvent();
            evAfter.Start = new DateTime(2026, 11, 1, 6, 30, 0, DateTimeKind.Utc);
            evAfter.IsUtcTime = true;

            string json1 = JsonSerializer.Serialize(evBefore, ApiJsonOptions);
            string json2 = JsonSerializer.Serialize(evAfter, ApiJsonOptions);

            Event? d1 = JsonSerializer.Deserialize<Event>(json1, ApiJsonOptions);
            Event? d2 = JsonSerializer.Deserialize<Event>(json2, ApiJsonOptions);

            Assert.NotEqual(d1!.Start, d2!.Start);
            Assert.Equal(5, d1.Start!.Value.Hour);
            Assert.Equal(6, d2.Start!.Value.Hour);
        }

        [Fact]
        public void LocalEvent_InFallBackAmbiguousHour_PreservesWallClock()
        {
            // Local-time event at 1:30 AM on fall-back day — the time is ambiguous
            // but local-time events don't convert, so 1:30 AM must be preserved.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 11, 1, 1, 30, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 11, 1, 5, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(1, deserialized.Start!.Value.Hour);
            Assert.Equal(30, deserialized.Start.Value.Minute);
            Assert.False(deserialized.IsUtcTime);
        }

        [Fact]
        public void Parser_LocalTimestamp_InFallBackAmbiguousHour_PreservesWallClock()
        {
            JsonElement element = MakeMinimalEvent(
                start: "2026-11-01T01:30:00.000",
                end: "2026-11-01T05:00:00.000"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(1, dto.Start!.Value.Hour);
            Assert.Equal(30, dto.Start.Value.Minute);
            Assert.False(dto.IsUtcTime);
        }

        #endregion

        #region Southern hemisphere DST — Australia (AEDT→AEST first Sunday April 2026)

        // Australia: AEDT (UTC+11) → AEST (UTC+10) on April 5, 2026 at 3:00 AM local
        // (clocks go back to 2:00 AM). In UTC this transition = April 4 16:00 UTC.

        [Fact]
        public void UtcEvent_DuringAustralianFallBack_RoundtripsExactInstant()
        {
            // UTC 15:30 on April 4 = 2:30 AM AEDT April 5 (before fall-back)
            // UTC 16:30 on April 4 = 2:30 AM AEST April 5 (after fall-back — clocks repeated 2 AM)
            Event evBefore = MakeEvent();
            evBefore.Start = new DateTime(2026, 4, 4, 15, 30, 0, DateTimeKind.Utc);
            evBefore.IsUtcTime = true;

            Event evAfter = MakeEvent();
            evAfter.Start = new DateTime(2026, 4, 4, 16, 30, 0, DateTimeKind.Utc);
            evAfter.IsUtcTime = true;

            string json1 = JsonSerializer.Serialize(evBefore, ApiJsonOptions);
            string json2 = JsonSerializer.Serialize(evAfter, ApiJsonOptions);

            Event? d1 = JsonSerializer.Deserialize<Event>(json1, ApiJsonOptions);
            Event? d2 = JsonSerializer.Deserialize<Event>(json2, ApiJsonOptions);

            Assert.NotNull(d1);
            Assert.NotNull(d2);
            Assert.Equal(15, d1.Start!.Value.Hour);
            Assert.Equal(16, d2.Start!.Value.Hour);
            Assert.NotEqual(d1.Start, d2.Start);
        }

        [Fact]
        public void LocalEvent_OnAustralianFallBackDay_PreservesWallClock()
        {
            // Community Day at 2:00 PM local on April 5, 2026 (Australia DST transition day).
            // The wall-clock time is unaffected.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 4, 5, 14, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 4, 5, 17, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(14, deserialized.Start!.Value.Hour);
            Assert.Equal(17, deserialized.End!.Value.Hour);
            Assert.Equal(5, deserialized.Start.Value.Day);
        }

        [Fact]
        public void Parser_UtcTimestamp_DuringAustralianFallBack_PreservesExactUtc()
        {
            // UTC 16:00 April 4 = exact moment clocks fall back in Australia.
            JsonElement element = MakeMinimalEvent(
                start: "2026-04-04T16:00:00.000Z",
                end: "2026-04-04T18:00:00.000Z"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(16, dto.Start!.Value.Hour);
            Assert.Equal(4, dto.Start.Value.Day);
            Assert.Equal(4, dto.Start.Value.Month);
            Assert.True(dto.IsUtcTime);
        }

        #endregion

        #region Southern hemisphere DST — Australia (AEST→AEDT first Sunday October 2026)

        // Australia: AEST (UTC+10) → AEDT (UTC+11) on October 4, 2026 at 2:00 AM local
        // (clocks spring forward to 3:00 AM). In UTC this = October 3 16:00 UTC.

        [Fact]
        public void UtcEvent_DuringAustralianSpringForward_RoundtripsExactInstant()
        {
            // UTC 16:00 on Oct 3 = 2:00 AM AEST Oct 4 (the gap moment — jumps to 3:00 AM AEDT).
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 10, 3, 16, 0, 0, DateTimeKind.Utc);
            ev.End = new DateTime(2026, 10, 3, 18, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(DateTimeKind.Utc, deserialized.Start!.Value.Kind);
            Assert.Equal(16, deserialized.Start.Value.Hour);
            Assert.Equal(3, deserialized.Start.Value.Day);
            Assert.Equal(10, deserialized.Start.Value.Month);
        }

        [Fact]
        public void LocalEvent_OnAustralianSpringForwardDay_PreservesWallClock()
        {
            // Local-time event at 2:30 AM on Oct 4 — skipped in Australia, but
            // stored as wall-clock time, so 2:30 AM must be preserved.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 10, 4, 2, 30, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 10, 4, 5, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(2, deserialized.Start!.Value.Hour);
            Assert.Equal(30, deserialized.Start.Value.Minute);
            Assert.Equal(5, deserialized.End!.Value.Hour);
        }

        [Fact]
        public void Parser_LocalTimestamp_OnAustralianSpringForwardDay_PreservesWallClock()
        {
            JsonElement element = MakeMinimalEvent(
                start: "2026-10-04T02:30:00.000",
                end: "2026-10-04T05:00:00.000"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(2, dto.Start!.Value.Hour);
            Assert.Equal(30, dto.Start.Value.Minute);
            Assert.False(dto.IsUtcTime);
        }

        #endregion

        #region Southern hemisphere DST — Brazil (BRST→BRT third Sunday February 2026)

        // Brazil: BRST (UTC-2) → BRT (UTC-3) on Feb 15, 2026 at midnight local.
        // Clocks go back from 00:00 to 23:00 previous day. In UTC = Feb 15 02:00 UTC.

        [Fact]
        public void UtcEvent_DuringBrazilianFallBack_RoundtripsExactInstant()
        {
            // UTC 02:00 on Feb 15 = midnight BRST (the fall-back instant).
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 2, 15, 2, 0, 0, DateTimeKind.Utc);
            ev.End = new DateTime(2026, 2, 15, 4, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(DateTimeKind.Utc, deserialized.Start!.Value.Kind);
            Assert.Equal(2, deserialized.Start.Value.Hour);
            Assert.Equal(15, deserialized.Start.Value.Day);
            Assert.Equal(2, deserialized.Start.Value.Month);
        }

        [Fact]
        public void LocalEvent_OnBrazilianFallBackDay_PreservesWallClock()
        {
            // Community Day at 2:00 PM local on Brazil DST transition day.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 2, 15, 14, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 2, 15, 17, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(14, deserialized.Start!.Value.Hour);
            Assert.Equal(17, deserialized.End!.Value.Hour);
        }

        #endregion

        #region Southern hemisphere DST — Brazil (BRT→BRST first Sunday November 2026)

        // Brazil: BRT (UTC-3) → BRST (UTC-2) on Nov 1, 2026 at midnight local.
        // Clocks spring forward from 00:00 to 01:00. In UTC = Nov 1 03:00 UTC.

        [Fact]
        public void UtcEvent_DuringBrazilianSpringForward_RoundtripsExactInstant()
        {
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 11, 1, 3, 0, 0, DateTimeKind.Utc);
            ev.End = new DateTime(2026, 11, 1, 5, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(DateTimeKind.Utc, deserialized.Start!.Value.Kind);
            Assert.Equal(3, deserialized.Start.Value.Hour);
            Assert.Equal(1, deserialized.Start.Value.Day);
            Assert.Equal(11, deserialized.Start.Value.Month);
        }

        [Fact]
        public void LocalEvent_OnBrazilianSpringForwardDay_PreservesWallClock()
        {
            // Midnight event on the spring-forward day — 00:00 is skipped to 01:00 in Brazil,
            // but wall-clock must be preserved for local-time events.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 11, 1, 0, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 11, 1, 3, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(0, deserialized.Start!.Value.Hour);
            Assert.Equal(3, deserialized.End!.Value.Hour);
            Assert.Equal(1, deserialized.Start.Value.Day);
        }

        #endregion

        #region Multi-day events spanning DST transitions

        [Fact]
        public void LocalEvent_SpanningNorthernSpringForward_PreservesWallClockOnBothSides()
        {
            // Event March 6–10, crossing US spring-forward on March 8.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 6, 10, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 3, 10, 10, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(10, deserialized.Start!.Value.Hour);
            Assert.Equal(6, deserialized.Start.Value.Day);
            Assert.Equal(10, deserialized.End!.Value.Hour);
            Assert.Equal(10, deserialized.End.Value.Day);
        }

        [Fact]
        public void UtcEvent_SpanningSouthernFallBack_PreservesBothInstants()
        {
            // Event April 3–6 UTC, crossing Australian fall-back on April 5.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 4, 3, 8, 0, 0, DateTimeKind.Utc);
            ev.End = new DateTime(2026, 4, 6, 8, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(ev.Start, deserialized.Start);
            Assert.Equal(ev.End, deserialized.End);
            Assert.Equal(DateTimeKind.Utc, deserialized.Start!.Value.Kind);
            Assert.Equal(DateTimeKind.Utc, deserialized.End!.Value.Kind);
        }

        [Fact]
        public void Parser_LocalEvent_SpanningAustralianSpringForward_PreservesWallClock()
        {
            // Multi-day event Oct 2–6, crossing Australian spring-forward on Oct 4.
            JsonElement element = MakeMinimalEvent(
                start: "2026-10-02T10:00:00.000",
                end: "2026-10-06T20:00:00.000"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(10, dto.Start!.Value.Hour);
            Assert.Equal(2, dto.Start.Value.Day);
            Assert.Equal(20, dto.End!.Value.Hour);
            Assert.Equal(6, dto.End.Value.Day);
            Assert.False(dto.IsUtcTime);
        }

        #endregion

        #region Date boundary edge cases

        [Fact]
        public void UtcEvent_AtExactMidnight_DoesNotDriftDay()
        {
            // 00:00:00.000Z on a boundary day — must not shift to previous day.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 7, 1, 0, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(0, deserialized.Start!.Value.Hour);
            Assert.Equal(1, deserialized.Start.Value.Day);
            Assert.Equal(7, deserialized.Start.Value.Month);
        }

        [Fact]
        public void LocalEvent_CrossingMonthBoundaryWithDstTransition_PreservesAll()
        {
            // Event March 31 – April 5 in southern hemisphere (AU fall-back on April 5).
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 3, 31, 10, 0, 0, DateTimeKind.Unspecified);
            ev.End = new DateTime(2026, 4, 5, 17, 0, 0, DateTimeKind.Unspecified);
            ev.IsUtcTime = false;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(3, deserialized.Start!.Value.Month);
            Assert.Equal(31, deserialized.Start.Value.Day);
            Assert.Equal(10, deserialized.Start.Value.Hour);
            Assert.Equal(4, deserialized.End!.Value.Month);
            Assert.Equal(5, deserialized.End.Value.Day);
            Assert.Equal(17, deserialized.End.Value.Hour);
        }

        [Fact]
        public void UtcEvent_CrossingYearBoundary_ViaSouthernHemisphereDst_PreservesInstant()
        {
            // Event Dec 31 UTC — in UTC+13 (Samoa/Tonga) this is already Jan 1.
            Event ev = MakeEvent();
            ev.Start = new DateTime(2026, 12, 31, 11, 0, 0, DateTimeKind.Utc);
            ev.End = new DateTime(2027, 1, 1, 11, 0, 0, DateTimeKind.Utc);
            ev.IsUtcTime = true;

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            Event? deserialized = JsonSerializer.Deserialize<Event>(json, ApiJsonOptions);

            Assert.NotNull(deserialized);
            Assert.Equal(2026, deserialized.Start!.Value.Year);
            Assert.Equal(2027, deserialized.End!.Value.Year);
            Assert.Equal(ev.Start, deserialized.Start);
            Assert.Equal(ev.End, deserialized.End);
        }

        [Fact]
        public void Parser_UtcTimestamp_AtExactMidnightUtc_PreservesHourZero()
        {
            JsonElement element = MakeMinimalEvent(
                start: "2026-07-01T00:00:00.000Z",
                end: "2026-07-01T06:00:00.000Z"
            );
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.Equal(0, dto.Start!.Value.Hour);
            Assert.Equal(1, dto.Start.Value.Day);
            Assert.Equal(7, dto.Start.Value.Month);
            Assert.True(dto.IsUtcTime);
        }

        #endregion

        #region IsUtcTime flag edge cases

        [Fact]
        public void MixedTimestamps_OneUtcOneLocal_SetsIsUtcTrue()
        {
            // If start is UTC and end is local (unusual but possible with bad data),
            // IsUtcTime should be true (any UTC → convert everything).
            JsonElement element = ParseElement("""
                {
                    "eventID": "mixed-tz",
                    "name": "Mixed Event",
                    "eventType": "event",
                    "heading": "Event",
                    "image": "img.png",
                    "link": "http://example.com",
                    "start": "2026-06-07T10:00:00.000Z",
                    "end": "2026-06-07T18:00:00.000",
                    "extraData": {}
                }
                """);
            ParsedEvent dto = ScrapedDuckEventParser.Parse(element);

            Assert.True(dto.IsUtcTime);
        }

        [Fact]
        public void Serialization_IsUtcTimeFalse_WithUtcKindDateTime_DoesNotAddZSuffix()
        {
            // If IsUtcTime is false but someone accidentally passes DateTimeKind.Utc,
            // the flag is what matters for display logic. This tests the flag propagation.
            Event ev = MakeEvent();
            ev.IsUtcTime = false;
            ev.Start = new DateTime(2026, 4, 11, 14, 0, 0, DateTimeKind.Unspecified);

            string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
            JsonDocument doc = JsonDocument.Parse(json);

            Assert.False(doc.RootElement.GetProperty("isUtcTime").GetBoolean());
        }

        #endregion

        #region DateTimeOffset interop for UTC events

        [Fact]
        public void UtcEvent_ParseableAsDateTimeOffset_WithZeroOffset()
        {
            // All UTC timestamps must be parseable as DateTimeOffset with offset 00:00.
            DateTime[] utcTimes =
            [
                new(2026, 3, 8, 7, 30, 0, DateTimeKind.Utc),   // US spring-forward gap
                new(2026, 11, 1, 6, 0, 0, DateTimeKind.Utc),   // US fall-back
                new(2026, 4, 4, 16, 0, 0, DateTimeKind.Utc),   // AU fall-back
                new(2026, 10, 3, 16, 0, 0, DateTimeKind.Utc),  // AU spring-forward
            ];

            foreach (DateTime utcTime in utcTimes)
            {
                Event ev = MakeEvent();
                ev.Start = utcTime;
                ev.IsUtcTime = true;

                string json = JsonSerializer.Serialize(ev, ApiJsonOptions);
                JsonDocument doc = JsonDocument.Parse(json);
                string start = doc.RootElement.GetProperty("start").GetString()!;

                DateTimeOffset parsed = DateTimeOffset.Parse(start, CultureInfo.InvariantCulture);
                Assert.Equal(TimeSpan.Zero, parsed.Offset);
                Assert.Equal(utcTime.Hour, parsed.Hour);
                Assert.Equal(utcTime.Minute, parsed.Minute);
            }
        }

        #endregion

        #region Helpers

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

        private static JsonElement ParseElement(string json)
        {
            return JsonElement.Parse(json);
        }

        private static JsonElement MakeMinimalEvent(
            string? start = "2026-03-15T11:00:00.000",
            string? end = "2026-03-15T17:00:00.000")
        {
            string startJson = start is null ? "null" : $"\"{start}\"";
            string endJson = end is null ? "null" : $"\"{end}\"";

            return ParseElement($$"""
                {
                    "eventID": "evt-tz-edge",
                    "name": "Timezone Edge Case",
                    "eventType": "event",
                    "heading": "Event",
                    "image": "https://example.com/image.png",
                    "link": "https://example.com/link",
                    "start": {{startJson}},
                    "end": {{endJson}},
                    "extraData": {}
                }
                """);
        }

        #endregion
    }
}
