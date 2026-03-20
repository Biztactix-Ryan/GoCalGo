# Architectural Decisions — Pokemon Go Events Calendar

Decisions are recorded as lightweight ADRs (Architectural Decision Records).

## ADR-001: Flutter for cross-platform mobile development

- **Date:** 2026-03-20
- **Status:** Accepted
- **Context:** The app needs to run on both iOS and Android. Maintaining two native codebases for a solo developer is impractical. The main alternatives considered were Flutter, React Native, and .NET MAUI.
- **Decision:** Use Flutter (Dart) as the mobile framework.
- **Consequences:** Single codebase covers both platforms. Dart is a new language in the stack (the backend is C#/.NET), which means context-switching between languages. Flutter has strong community support and a mature package ecosystem for calendar UIs and Firebase integration. Build tooling for both app stores is well-documented.

## ADR-002: .NET minimal APIs as the backend layer

- **Date:** 2026-03-20
- **Status:** Accepted
- **Context:** The Flutter app needs a backend to cache event data, manage device tokens, and schedule push notifications. Hitting the ScrapedDuck API directly from the app would create a hard dependency on an external community project with no SLA.
- **Decision:** Build a .NET minimal API backend in C# to sit between the app and external services.
- **Consequences:** Adds a backend service to host and maintain, but provides control over data shaping, caching, and notification scheduling. .NET minimal APIs are lightweight and familiar. The backend can be extended later without changing the app. Runs as a Docker container on existing Coolify infrastructure.

## ADR-003: ScrapedDuck as the primary event data source

- **Date:** 2026-03-20
- **Status:** Accepted
- **Context:** Niantic does not provide a public API for Pokemon Go events. Event data must come from community sources. ScrapedDuck is a widely-used open-source project that scrapes LeekDuck.com and serves structured JSON data. Other sites (PoGo Hub, Serebii, Dexerto) publish event info but not as consumable APIs.
- **Decision:** Use ScrapedDuck's JSON API as the primary event data source.
- **Consequences:** Dependency on a community-maintained project with no uptime guarantee. If ScrapedDuck goes down or changes format, the backend must handle it gracefully (serve cached data, alert for manual intervention). The Redis and PostgreSQL caching layers mitigate short-term outages. A fallback data entry mechanism may be needed long-term.

## ADR-004: Anonymous usage with device-scoped identity

- **Date:** 2026-03-20
- **Status:** Accepted
- **Context:** The app's core functionality (viewing events) doesn't require user identity. Push notifications require a device token but not a user account. Adding authentication increases complexity and creates a barrier to entry.
- **Decision:** Launch without user authentication. Use FCM device tokens as the sole device identifier for push notification preferences.
- **Consequences:** Zero friction onboarding — open the app and start using it. No PII collected, minimal compliance burden. Trade-off: no cross-device sync, no account recovery, no personalisation beyond device-local flags. Authentication can be layered on later if needed without breaking existing functionality.

## ADR-005: Redis for event data caching

- **Date:** 2026-03-20
- **Status:** Accepted
- **Context:** Event data is read-heavy and changes infrequently (new events are announced days or weeks in advance, active event lists change at most a few times per day). The backend fetches from ScrapedDuck on a schedule and serves many app instances from the same data.
- **Decision:** Use Redis as a cache layer between the .NET API and PostgreSQL for hot event data.
- **Consequences:** Fast responses for the most common queries ("what's active today"). Reduces PostgreSQL load. Adds Redis as an infrastructure dependency. Cache invalidation is straightforward since the ingestion job controls when data changes — cache can be refreshed on each successful fetch.
