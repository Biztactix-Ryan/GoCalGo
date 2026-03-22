# Pokemon Go Events Calendar (GoCalGo)

## Overview
A mobile application for Pokemon Go players that aggregates event data and presents it as a clear, daily view of active buffs and bonuses. The core problem it solves is cutting through Niantic's scattered event announcements to answer one simple question: "What's boosted today?"

## Team
Solo project. Ryan Tregea handles all development — Flutter frontend, .NET backend, and infrastructure.

## Architecture

### Tech Stack
- **Mobile App:** Flutter (Dart) — single codebase for iOS and Android
- **Backend API:** .NET minimal APIs (C#) — lightweight REST API with background jobs
- **Database:** PostgreSQL — cached event data, device tokens, user event flags
- **Cache:** Redis — in-memory cache for hot event data
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Event Data Source:** ScrapedDuck API (community-maintained, scrapes LeekDuck.com)
- **Hosting:** Docker on Coolify (self-hosted)

### Components
- **Flutter App:** UI layer — daily event calendar, local event flags, FCM token registration
- **.NET Minimal API:** Backend — fetches/caches events from ScrapedDuck, serves shaped data, schedules push notifications
- **PostgreSQL:** Persistent storage for events, device tokens, flags
- **Redis:** Cache-aside layer for read-heavy event queries

### Data Flow
1. Scheduled .NET background job fetches events from ScrapedDuck → normalizes → stores in PostgreSQL + Redis
2. Flutter app calls .NET API → served from Redis (cache hit) or PostgreSQL (cache miss) → stored locally on device
3. User flags event → stored locally + sent to backend (event ID + FCM token) for notification scheduling
4. Backend monitors flagged events → sends FCM push when event end time approaches in user's local timezone

## Key Decisions
- Flutter over React Native/MAUI — single codebase, strong calendar UI ecosystem (ADR-001)
- .NET backend as caching/notification layer — insulates app from ScrapedDuck instability (ADR-002)
- ScrapedDuck as data source — only structured JSON API for PoGo events available (ADR-003)
- Anonymous/device-scoped identity via FCM tokens — zero friction, no PII (ADR-004)
- Redis cache-aside pattern — event data is read-heavy, changes infrequently (ADR-005)

## Dependencies
- ScrapedDuck API (external, no SLA — cache aggressively)
- Firebase Cloud Messaging (push notifications)
- Coolify (CI/CD and hosting)

## Development Setup
TBD — repository structure not yet established. Expected: local Docker Compose stack for backend services.

## Status
Greenfield — pre-development. Project documentation phase.

---
*Last reviewed: 2026-03-20*
*Update this document when architecture changes.*