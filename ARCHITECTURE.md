# Architecture — Pokemon Go Events Calendar

## System Overview
A two-tier architecture: a Flutter mobile app communicating with a .NET minimal API backend. The backend acts as a caching and notification layer between the app and external data sources (ScrapedDuck for events, Firebase for push notifications). The app syncs event data to the device for offline access and sends flag/notification preferences to the backend.

This pattern was chosen because:
- The Flutter app needs a stable, shaped API rather than depending directly on a community-run scraper
- Caching at the backend reduces load on ScrapedDuck and insulates the app from upstream outages
- Push notification scheduling requires server-side logic to monitor event end times and trigger FCM

## Component Map

    [Flutter App (iOS/Android)]
            |
            v
    [.NET Minimal API]
        |       |       \
        v       v        v
    [PostgreSQL] [Redis]  [Firebase Cloud Messaging]
                            |
        [ScrapedDuck API] --+-- (fetched by .NET backend on schedule)

- **Flutter App:** UI layer. Displays daily event calendar, manages local event flags, registers FCM device tokens with the backend.
- **.NET Minimal API:** Core backend. Fetches and caches event data from ScrapedDuck, serves shaped event data to the app, stores device tokens and flag preferences, schedules push notifications via FCM.
- **PostgreSQL:** Persistent storage for cached event data, device tokens, and user event flags.
- **Redis:** Short-lived cache for event data. Reduces database load and speeds up API responses for frequently requested data (e.g. "today's events").
- **Firebase Cloud Messaging:** Delivers push notifications to iOS and Android devices.
- **ScrapedDuck API:** External data source. Provides Pokemon Go event data as JSON, scraped from LeekDuck.com.

## Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Mobile app | Flutter (Dart) | Single codebase for iOS and Android. Strong ecosystem for calendar/list UIs. |
| Backend API | .NET minimal APIs (C#) | Lightweight, fast, familiar. Good fit for a focused REST API with background jobs. |
| Database | PostgreSQL | Reliable, well-supported. Handles structured event data and relational queries well. |
| Cache | Redis | Fast in-memory cache for hot event data. Simple key-value model suits this use case. |
| Push notifications | Firebase Cloud Messaging | Industry standard for mobile push. Native Flutter support via `firebase_messaging` package. |
| Event data | ScrapedDuck API | Community-maintained, free, JSON-based. The de facto source for Pokemon Go event data. |
| Container orchestration | Docker on Coolify | Consistent with existing infrastructure. Handles builds, deploys, and service management. |

## Data Flow

1. **Event ingestion:** A scheduled background job in the .NET API fetches event data from ScrapedDuck periodically (e.g. every 15-30 minutes). Raw event data is parsed, normalised, and stored in PostgreSQL. A summarised version is cached in Redis.

2. **App data sync:** The Flutter app calls the .NET API to fetch current and upcoming events. The API serves from Redis cache where possible, falling back to PostgreSQL. The app stores the event data locally on-device for offline access.

3. **Event flagging:** When a user flags an event, the preference is stored locally on-device. The app also sends the flag (event ID + FCM device token) to the backend so push notifications can be scheduled.

4. **Push notifications:** The .NET backend monitors flagged events. When a flagged event's end time approaches in the user's local timezone, the backend sends a push notification via FCM to the registered device token.

5. **Timezone handling:** Pokemon Go events use local time — an event scheduled for 2-5pm happens at 2-5pm in every timezone as the day progresses. The app uses the device's local timezone to display events. The backend must account for local time when scheduling push notifications (i.e. a "2pm" event ends at different UTC times depending on the user's timezone).

## Key Patterns
- **Cache-aside:** Redis cache sits in front of PostgreSQL for read-heavy event data. Cache is populated on miss or by the ingestion job.
- **Background job scheduling:** Periodic event fetching from ScrapedDuck and push notification scheduling run as background tasks in the .NET API (likely using a hosted service or Hangfire, TBD).
- **Device-scoped identity:** No user accounts. Device identity is established via FCM tokens. All user-specific data (flags, notification preferences) is keyed to device tokens.
- **Offline-first reads:** The Flutter app caches event data locally. Network calls update the cache but aren't required for basic functionality.

## Integration Points

| System | Direction | Protocol | Notes |
|--------|-----------|----------|-------|
| ScrapedDuck API | Inbound (backend fetches) | HTTPS/JSON | Community-run, no SLA. Cache aggressively. |
| Firebase Cloud Messaging | Outbound (backend sends) | HTTPS (FCM API) | Requires Firebase project and service account credentials. |
| Apple Push Notification Service | Outbound (via FCM) | Handled by FCM | FCM abstracts APNS for iOS devices. |
| Google Play Services | Outbound (via FCM) | Handled by FCM | FCM native integration for Android. |
