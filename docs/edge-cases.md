# Edge Cases: Multi-Day Events, Recurring Events, and Timezone Quirks

Catalogue of edge cases identified from ScrapedDuck API analysis that the GoCalGo backend and Flutter app must handle correctly.

**Source story:** US-GCG-20 — ScrapedDuck API exploration and data contract definition

---

## 1. Multi-Day Events

### 1.1 Events spanning multiple calendar days

Many Pokemon GO events run for several days (e.g. Go Fest, Safari Zone, seasonal events). The `start` and `end` timestamps in ScrapedDuck are straightforward, but the calendar UI must render these across day boundaries.

**Example:** A 5-day event with `start: "2026-06-05T10:00:00.000"` and `end: "2026-06-09T20:00:00.000"` should appear on all five days in the daily view.

**Handling:**
- The backend or app must expand multi-day events across all intermediate days when building the daily view.
- Display logic should show "Day 2 of 5" or similar context.

### 1.2 Events with null start or end times

ScrapedDuck allows `start` and `end` to be `null`. This occurs with:
- **Seasons:** Often have no explicit start/end (the season just runs until the next one).
- **Ongoing features:** Some events or updates have a start but no end.

**Handling:**
- Null `start`: Treat as "already active" — show on all days until `end`.
- Null `end`: Treat as "no known end" — show from `start` onwards. Cap display at a reasonable horizon (e.g. 30 days) to avoid infinite calendar entries.
- Both null: Treat as informational/evergreen — show in a separate "ongoing" section rather than on specific days.

### 1.3 Overlapping events

Multiple events frequently run simultaneously (e.g. a season, a week-long event, a raid hour, and a spotlight hour can all be active on the same Tuesday evening).

**Handling:**
- The daily view must stack/list all active events for a given day.
- Consider priority ordering: short-duration events (raid hour, spotlight hour) are more actionable and should appear above long-running background events (seasons).

### 1.4 Events with different buff windows within a single event

Community Day has a 3-hour core window with certain buffs, but some buffs (marked with `*` in `bonusDisclaimers`) extend to a longer window (e.g. the full day). The API represents this as a single event with one `start`/`end`, not as separate sub-events.

**Handling:**
- Parse `bonusDisclaimers` to surface the extended window info.
- Consider displaying a note like "Some bonuses active all day" when disclaimers are present.
- Do NOT try to split into sub-events — the API doesn't provide separate timestamps for extended windows.

---

## 2. Recurring Events

### 2.1 Weekly Spotlight Hour

Spotlight Hour runs **every Tuesday 6:00–7:00 PM local time**. ScrapedDuck lists each week's Spotlight Hour as a separate event with its own `eventID`, `start`, and `end`.

**Edge case:** If ScrapedDuck only publishes Spotlight Hours a few weeks ahead, the app may show a gap in future weeks. The backend should NOT fabricate future events.

**Handling:**
- Treat each occurrence as an independent event (which is how ScrapedDuck models them).
- No special "recurring" logic needed — each week is a distinct API object.

### 2.2 Weekly Raid Hour

Raid Hour runs **every Wednesday 6:00–7:00 PM local time**. Same pattern as Spotlight Hour — each week is a separate event in ScrapedDuck.

**Handling:** Same as Spotlight Hour — treat each as independent.

### 2.3 Research Breakthroughs

Research Breakthroughs rotate on a monthly cadence. ScrapedDuck lists them as events spanning the full month (or rotation period).

**Edge case:** A research breakthrough event might span `start: "2026-03-01T13:00:00.000"` to `end: "2026-04-01T13:00:00.000"` — exactly one month. This is a multi-day event that should appear on the daily view, but showing it every day for 31 days may be noisy.

**Handling:**
- Events of type `research-breakthrough` could be shown in a persistent/pinned section rather than as daily entries.
- Or show only on the start day and in an "active events" sidebar.

### 2.4 Seasons

Seasons span ~3 months and define ongoing background bonuses (hemisphere-specific spawns, egg pools, etc.). ScrapedDuck lists them as single events with `eventType: "season"`.

**Handling:**
- Seasons are contextual background — show in a dedicated "Current Season" section, not as daily events.
- A season's buff data is NOT structured in `extraData` — only the event name and image are available.

### 2.5 Max Mondays

Max Mondays run **every Monday**, a relatively new recurring event. Same ScrapedDuck pattern — separate event objects per week.

**Handling:** Same as Spotlight/Raid Hour.

---

## 3. Timezone Quirks

### 3.1 Local time with no timezone offset (with GBL exception)

ScrapedDuck timestamps are ISO 8601 **without timezone offset**: `"2026-04-11T14:00:00.000"`. These represent **local time** — Pokemon GO events happen at the same wall-clock time worldwide (e.g. Community Day is 2–5 PM in every timezone).

**Exception: GO Battle League events** include a `Z` (UTC) suffix: `"2026-03-17T20:00:00.000Z"`. GBL seasons start and end simultaneously worldwide, so UTC timestamps are correct for these.

**This is the most critical edge case in the system.**

**Handling:**
- The backend must detect whether a timestamp ends with `Z` — if so, treat as UTC; otherwise, treat as local time.
- For local-time events: store as-is, display directly, schedule notifications per user timezone.
- For UTC events (GBL): convert to user's local time for display and notifications.
- For push notifications, the backend must know the user's timezone (from FCM token registration) to compute the correct UTC moment for each user.
- Example: "Event starts at 14:00" means 14:00 in New York (18:00 UTC) AND 14:00 in Tokyo (05:00 UTC). Notifications must fire at different UTC times per user.

### 3.2 DST transitions during events

If a multi-day event spans a DST transition (e.g. US spring-forward in March), the wall-clock time remains the same but the UTC offset shifts.

**Example:** An event running March 7–14 with daily hours 10:00–17:00. On March 9 (spring-forward), clocks skip 2:00 AM → 3:00 AM. The event still runs 10:00–17:00 local time, but that's now UTC-4 instead of UTC-5.

**Handling:**
- Since timestamps are local time with no offset, display is unaffected.
- Notification scheduling must recompute UTC offsets when DST changes. The backend should resolve timezone at notification-send time, not at event-ingest time.
- Use IANA timezone database (e.g. `America/New_York`), never fixed UTC offsets.

### 3.3 Events crossing midnight local time

Some events end at or past midnight (e.g. `end: "2026-03-02T00:00:00.000"` or `end: "2026-03-02T02:00:00.000"`). This means the event is active on the calendar day before the `end` date.

**Handling:**
- When building the daily view for March 1, include events whose `end` extends into March 2 (up to, say, 4:00 AM as a threshold — matching typical PoGo event patterns).
- This is a UI decision, not an API issue.

### 3.4 International Date Line edge cases

Players near the International Date Line (e.g. Tonga, Samoa, Kiribati) are the first/last to experience events. Since ScrapedDuck uses local time, this is handled naturally. However:

- A user viewing the calendar in UTC+13 (Tonga) would see Monday's Raid Hour while users in UTC-11 (American Samoa) are still on Sunday.
- The calendar should always use the device's local date, which handles this automatically.

**Handling:** No special logic needed — device timezone handles this. Just ensure the app never converts timestamps to/from UTC for display.

### 3.5 Events with fixed UTC times (rare exceptions)

While most PoGo events use local time, some global events (e.g. GO Fest finales, global raid challenges) have simultaneous worldwide start times. ScrapedDuck still represents these without timezone info, but they may describe UTC times in the event name or linked page.

**Handling:**
- There is no reliable way to distinguish local-time events from UTC-time events in ScrapedDuck data.
- Default to treating all times as local time (correct for 99% of events).
- If a future version of the API adds timezone metadata, adapt the DTO accordingly.
- Accept this as a known limitation and document it for users.

### 3.6 Timestamp precision inconsistency

ScrapedDuck timestamps include milliseconds (`"2026-04-11T14:00:00.000"`) but the precision is always `.000`. Some events may omit the milliseconds entirely.

**Handling:**
- Parse both `"2026-04-11T14:00:00.000"` and `"2026-04-11T14:00:00"` as equivalent.
- Standard ISO 8601 parsers handle this automatically.

---

## 4. Combined Edge Cases (Multi-Day + Recurring + Timezone)

### 4.1 Community Day extended window crossing midnight

Community Day core hours are typically 2–5 PM, but extended windows (evolution moves, trade bonuses) may run until midnight or later. The extended window isn't a separate event — it's described in `bonusDisclaimers`.

**Risk:** If the extended window runs "until 10 PM" but the user is in a timezone where 10 PM falls after midnight UTC, notification scheduling must use local time, not UTC.

### 4.2 Multi-day event starting mid-day

An event with `start: "2026-06-05T10:00:00.000"` starts at 10 AM local time. On the first day, buffs are active for only part of the day. On subsequent days, they may be active all day (or follow a specific daily window described on LeekDuck, not in the API).

**Risk:** ScrapedDuck only provides the overall event window, not daily active hours for multi-day events. The app should show the event on all days but note that the first/last days may be partial.

### 4.3 Back-to-back weekly events with different data

Spotlight Hour one week may feature 2x Transfer Candy, and the next week 2x Catch Candy. Each is a separate ScrapedDuck event. If the data refresh is slow (~12 hours), the app could briefly show stale data for the next week's event.

**Handling:** Cache TTL should be short enough to pick up changes before weekly events, and the UI should show a "last updated" indicator.

---

## Summary Table

| Edge Case | Severity | Component | Notes |
|-----------|----------|-----------|-------|
| Multi-day calendar spanning | High | Flutter UI | Must expand events across days |
| Null start/end | Medium | Backend + UI | Needs fallback display logic |
| Overlapping events | High | Flutter UI | Daily view must stack events |
| Extended buff windows | Low | Flutter UI | Informational, from disclaimers |
| Recurring events as separate objects | Low | Backend | No special logic — ScrapedDuck handles it |
| Research breakthrough noise | Low | Flutter UI | Consider pinned/persistent display |
| Season display | Low | Flutter UI | Separate section recommended |
| **Local time with no timezone (GBL uses UTC)** | **Critical** | **Backend** | **Notification scheduling requires user TZ; GBL events have Z suffix** |
| DST transitions | High | Backend | Recompute UTC at notification time |
| Midnight crossing | Medium | Flutter UI | Threshold-based day assignment |
| Fixed UTC events (rare) | Low | Both | Known limitation, no API signal |
| Timestamp precision | Low | Backend | Standard parsers handle it |

---

*Last updated: 2026-03-20*
*Derived from: ScrapedDuck API analysis (docs/scrapedduck-api.md), buff mapping (docs/buff-bonus-mapping.md), and Pokemon GO event patterns*
