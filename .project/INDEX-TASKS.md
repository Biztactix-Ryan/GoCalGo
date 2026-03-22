# Tasks

| ID | Title | Status | Points | Tags | Assignee | Depends On | Story |
| -- | ----- | ------ | ------ | ---- | -------- | ---------- | ----- |
| [US-GCG-1-1](tasks/US-GCG-1-1.md) | Test: Flutter project created with standard structure | ✅ done | 1 |  | claude | — | [US-GCG-1](stories/US-GCG-1.md) |
| [US-GCG-1-2](tasks/US-GCG-1-2.md) | Test: .NET minimal API project created with standard structure | ✅ done | 1 |  | — | US-GCG-1-7 | [US-GCG-1](stories/US-GCG-1.md) |
| [US-GCG-1-3](tasks/US-GCG-1-3.md) | Test: Solution/workspace file connects both projects | ✅ done | 1 |  | claude | — | [US-GCG-1](stories/US-GCG-1.md) |
| [US-GCG-1-4](tasks/US-GCG-1-4.md) | Test: README with setup instructions exists | ✅ done | 1 |  | claude | — | [US-GCG-1](stories/US-GCG-1.md) |
| [US-GCG-1-5](tasks/US-GCG-1-5.md) | Test: .gitignore covers Dart and .NET artifacts | ✅ done | 1 |  | claude | — | [US-GCG-1](stories/US-GCG-1.md) |
| [US-GCG-1-6](tasks/US-GCG-1-6.md) | Scaffold Flutter project with standard directory structure | ✅ done | 2 |  | claude | — | [US-GCG-1](stories/US-GCG-1.md) |
| [US-GCG-1-7](tasks/US-GCG-1-7.md) | Scaffold .NET minimal API project | ✅ done | 2 |  | claude | — | [US-GCG-1](stories/US-GCG-1.md) |
| [US-GCG-1-8](tasks/US-GCG-1-8.md) | Create repository structure and shared configuration | ✅ done | 1 |  | claude | US-GCG-1-6, US-GCG-1-7 | [US-GCG-1](stories/US-GCG-1.md) |
| [US-GCG-10-1](tasks/US-GCG-10-1.md) | Test: Flutter app requests and obtains FCM device token | ✅ done | 2 |  | claude | — | [US-GCG-10](stories/US-GCG-10.md) |
| [US-GCG-10-2](tasks/US-GCG-10-2.md) | Test: Token is sent to the .NET backend on first launch and on refresh | ✅ done | 2 |  | claude | — | [US-GCG-10](stories/US-GCG-10.md) |
| [US-GCG-10-3](tasks/US-GCG-10-3.md) | Test: Backend stores device tokens in PostgreSQL | ✅ done | 2 |  | claude | — | [US-GCG-10](stories/US-GCG-10.md) |
| [US-GCG-10-4](tasks/US-GCG-10-4.md) | Test: Backend validates incoming token registrations to prevent abuse | ✅ done | 2 |  | claude | — | [US-GCG-10](stories/US-GCG-10.md) |
| [US-GCG-10-5](tasks/US-GCG-10-5.md) | Test: Token refresh is handled automatically when FCM rotates tokens | ✅ done | 2 |  | claude | — | [US-GCG-10](stories/US-GCG-10.md) |
| [US-GCG-10-6](tasks/US-GCG-10-6.md) | Integrate firebase_messaging package in Flutter | ✅ done | 2 |  | claude | — | [US-GCG-10](stories/US-GCG-10.md) |
| [US-GCG-10-7](tasks/US-GCG-10-7.md) | Implement backend device token registration endpoint | ✅ done | 2 |  | claude | — | [US-GCG-10](stories/US-GCG-10.md) |
| [US-GCG-10-8](tasks/US-GCG-10-8.md) | Send token from Flutter to backend on launch and refresh | ✅ done | 1 |  | claude | US-GCG-10-6, US-GCG-10-7 | [US-GCG-10](stories/US-GCG-10.md) |
| [US-GCG-11-1](tasks/US-GCG-11-1.md) | Test: When a user flags an event the flag and FCM token are sent to the backend | ⚪ todo | 1 |  | — | — | [US-GCG-11](stories/US-GCG-11.md) |
| [US-GCG-11-10](tasks/US-GCG-11-10.md) | Implement unflag cancellation logic | ✅ done | 1 |  | claude | US-GCG-11-8 | [US-GCG-11](stories/US-GCG-11.md) |
| [US-GCG-11-2](tasks/US-GCG-11-2.md) | Test: Backend schedules a notification for the flagged event's end time minus a configurable buffer | ⚪ todo | 1 |  | — | — | [US-GCG-11](stories/US-GCG-11.md) |
| [US-GCG-11-3](tasks/US-GCG-11-3.md) | Test: Notification scheduling accounts for the user's local timezone | ✅ done | 2 |  | claude | — | [US-GCG-11](stories/US-GCG-11.md) |
| [US-GCG-11-4](tasks/US-GCG-11-4.md) | Test: Notifications are delivered via FCM to both iOS and Android | ✅ done | 3 |  | claude | — | [US-GCG-11](stories/US-GCG-11.md) |
| [US-GCG-11-5](tasks/US-GCG-11-5.md) | Test: Unflagging an event cancels the scheduled notification | ✅ done | 2 |  | claude | — | [US-GCG-11](stories/US-GCG-11.md) |
| [US-GCG-11-6](tasks/US-GCG-11-6.md) | Test: Notifications include event name and remaining time | ⚪ todo | 2 |  | — | — | [US-GCG-11](stories/US-GCG-11.md) |
| [US-GCG-11-7](tasks/US-GCG-11-7.md) | Implement backend flag sync endpoint | ✅ done | 2 |  | claude | — | [US-GCG-11](stories/US-GCG-11.md) |
| [US-GCG-11-8](tasks/US-GCG-11-8.md) | Implement notification scheduler service | ✅ done | 3 |  | claude | US-GCG-11-7 | [US-GCG-11](stories/US-GCG-11.md) |
| [US-GCG-11-9](tasks/US-GCG-11-9.md) | Implement FCM notification delivery | ⚪ todo | 2 |  | — | US-GCG-11-8 | [US-GCG-11](stories/US-GCG-11.md) |
| [US-GCG-12-1](tasks/US-GCG-12-1.md) | Test: Push notifications display correctly on both iOS and Android | ⚪ todo | 2 |  | — | — | [US-GCG-12](stories/US-GCG-12.md) |
| [US-GCG-12-2](tasks/US-GCG-12-2.md) | Test: Tapping a notification opens the app to the relevant event | ✅ done | 2 |  | claude | — | [US-GCG-12](stories/US-GCG-12.md) |
| [US-GCG-12-3](tasks/US-GCG-12-3.md) | Test: Notifications work when the app is in foreground background and terminated states | ✅ done | 3 |  | claude | — | [US-GCG-12](stories/US-GCG-12.md) |
| [US-GCG-12-4](tasks/US-GCG-12-4.md) | Test: iOS notification permissions are requested appropriately | ✅ done | 2 |  | claude | — | [US-GCG-12](stories/US-GCG-12.md) |
| [US-GCG-12-5](tasks/US-GCG-12-5.md) | Configure Flutter notification display and permissions | ✅ done | 2 |  | claude | — | [US-GCG-12](stories/US-GCG-12.md) |
| [US-GCG-12-6](tasks/US-GCG-12-6.md) | Implement notification tap handling and deep linking | ✅ done | 2 |  | claude | US-GCG-12-5 | [US-GCG-12](stories/US-GCG-12.md) |
| [US-GCG-13-1](tasks/US-GCG-13-1.md) | Test: App icon designed and exported for all required sizes (iOS and Android) | ⚪ todo | 2 |  | — | — | [US-GCG-13](stories/US-GCG-13.md) |
| [US-GCG-13-2](tasks/US-GCG-13-2.md) | Test: Splash screen implemented | ⚪ todo | 1 |  | — | — | [US-GCG-13](stories/US-GCG-13.md) |
| [US-GCG-13-3](tasks/US-GCG-13-3.md) | Test: App Store and Google Play listing descriptions written | ✅ done | 2 |  | claude | — | [US-GCG-13](stories/US-GCG-13.md) |
| [US-GCG-13-4](tasks/US-GCG-13-4.md) | Test: Screenshots captured for required device sizes | ✅ done | 2 |  | claude | — | [US-GCG-13](stories/US-GCG-13.md) |
| [US-GCG-13-5](tasks/US-GCG-13-5.md) | Test: Privacy policy page created (required for both stores) | ✅ done | 2 |  | claude | — | [US-GCG-13](stories/US-GCG-13.md) |
| [US-GCG-13-6](tasks/US-GCG-13-6.md) | Design and export app icons for all platforms | ✅ done | 2 |  | claude | — | [US-GCG-13](stories/US-GCG-13.md) |
| [US-GCG-13-7](tasks/US-GCG-13-7.md) | Implement splash screen | ✅ done | 1 |  | claude | — | [US-GCG-13](stories/US-GCG-13.md) |
| [US-GCG-13-8](tasks/US-GCG-13-8.md) | Write store listing metadata and create privacy policy | ✅ done | 2 |  | claude | — | [US-GCG-13](stories/US-GCG-13.md) |
| [US-GCG-14-1](tasks/US-GCG-14-1.md) | Test: App startup time is under 2 seconds | ✅ done | 2 |  | claude | — | [US-GCG-14](stories/US-GCG-14.md) |
| [US-GCG-14-2](tasks/US-GCG-14-2.md) | Test: Scrolling and transitions are smooth (60fps) | ✅ done | 2 |  | claude | — | [US-GCG-14](stories/US-GCG-14.md) |
| [US-GCG-14-3](tasks/US-GCG-14-3.md) | Test: Basic accessibility labels are on all interactive elements | ✅ done | 2 |  | claude | — | [US-GCG-14](stories/US-GCG-14.md) |
| [US-GCG-14-4](tasks/US-GCG-14-4.md) | Test: App works on small and large screen sizes | ✅ done | 2 |  | claude | — | [US-GCG-14](stories/US-GCG-14.md) |
| [US-GCG-14-5](tasks/US-GCG-14-5.md) | Test: Memory usage is reasonable and no leaks detected | ✅ done | 2 |  | claude | — | [US-GCG-14](stories/US-GCG-14.md) |
| [US-GCG-14-6](tasks/US-GCG-14-6.md) | Profile app performance and fix bottlenecks | ✅ done | 3 |  | claude | — | [US-GCG-14](stories/US-GCG-14.md) |
| [US-GCG-14-7](tasks/US-GCG-14-7.md) | Accessibility review and fixes | ✅ done | 2 |  | claude | — | [US-GCG-14](stories/US-GCG-14.md) |
| [US-GCG-15-1](tasks/US-GCG-15-1.md) | Test: iOS build signed and submitted to App Store Connect | ⚪ todo | 1 |  | — | — | [US-GCG-15](stories/US-GCG-15.md) |
| [US-GCG-15-2](tasks/US-GCG-15-2.md) | Test: Android build signed and submitted to Google Play Console | ⚪ todo | 1 |  | — | — | [US-GCG-15](stories/US-GCG-15.md) |
| [US-GCG-15-3](tasks/US-GCG-15-3.md) | Test: Both submissions pass initial automated review checks | ⚪ todo | 1 |  | — | — | [US-GCG-15](stories/US-GCG-15.md) |
| [US-GCG-15-4](tasks/US-GCG-15-4.md) | Test: App is approved and live on both stores | ⚪ todo | 1 |  | — | — | [US-GCG-15](stories/US-GCG-15.md) |
| [US-GCG-15-5](tasks/US-GCG-15-5.md) | Build and sign iOS release | ⚪ todo | 2 |  | — | — | [US-GCG-15](stories/US-GCG-15.md) |
| [US-GCG-15-6](tasks/US-GCG-15-6.md) | Build and sign Android release | ⚪ todo | 1 |  | — | — | [US-GCG-15](stories/US-GCG-15.md) |
| [US-GCG-15-7](tasks/US-GCG-15-7.md) | Submit for review and address feedback | ⚪ todo | 2 |  | — | US-GCG-15-5, US-GCG-15-6 | [US-GCG-15](stories/US-GCG-15.md) |
| [US-GCG-16-1](tasks/US-GCG-16-1.md) | Test: Firebase project created with appropriate naming | ✅ done | 1 |  | claude | — | [US-GCG-16](stories/US-GCG-16.md) |
| [US-GCG-16-2](tasks/US-GCG-16-2.md) | Test: FCM enabled in the Firebase console | ✅ done | 1 |  | claude | — | [US-GCG-16](stories/US-GCG-16.md) |
| [US-GCG-16-3](tasks/US-GCG-16-3.md) | Test: iOS and Android apps registered in Firebase | ✅ done | 1 |  | — | US-GCG-16-8 | [US-GCG-16](stories/US-GCG-16.md) |
| [US-GCG-16-4](tasks/US-GCG-16-4.md) | Test: google-services.json and GoogleService-Info.plist generated | ✅ done | 1 |  | claude | — | [US-GCG-16](stories/US-GCG-16.md) |
| [US-GCG-16-5](tasks/US-GCG-16-5.md) | Test: Firebase Admin SDK service account credentials generated for the .NET backend | ✅ done | 1 |  | claude | — | [US-GCG-16](stories/US-GCG-16.md) |
| [US-GCG-16-6](tasks/US-GCG-16-6.md) | Test: Credentials stored securely (not committed to git) | ✅ done | 1 |  | claude | — | [US-GCG-16](stories/US-GCG-16.md) |
| [US-GCG-16-7](tasks/US-GCG-16-7.md) | Create Firebase project and enable FCM | ✅ done | 1 |  | claude | — | [US-GCG-16](stories/US-GCG-16.md) |
| [US-GCG-16-8](tasks/US-GCG-16-8.md) | Register iOS and Android apps in Firebase | ✅ done | 1 |  | claude | — | [US-GCG-16](stories/US-GCG-16.md) |
| [US-GCG-16-9](tasks/US-GCG-16-9.md) | Configure Firebase credentials in project | ✅ done | 1 |  | claude | — | [US-GCG-16](stories/US-GCG-16.md) |
| [US-GCG-17-1](tasks/US-GCG-17-1.md) | Test: Apple Developer account configured with app ID and provisioning profile | ✅ done | 1 |  | — | — | [US-GCG-17](stories/US-GCG-17.md) |
| [US-GCG-17-2](tasks/US-GCG-17-2.md) | Test: Android keystore generated and stored securely | ✅ done | 1 |  | claude | — | [US-GCG-17](stories/US-GCG-17.md) |
| [US-GCG-17-3](tasks/US-GCG-17-3.md) | Test: Flutter build configs reference signing credentials via environment variables | ✅ done | 1 |  | claude | — | [US-GCG-17](stories/US-GCG-17.md) |
| [US-GCG-17-4](tasks/US-GCG-17-4.md) | Test: Release builds succeed for both iOS and Android | ✅ done | 2 |  | claude | — | [US-GCG-17](stories/US-GCG-17.md) |
| [US-GCG-17-5](tasks/US-GCG-17-5.md) | Test: Signing credentials are documented but not committed to git | ✅ done | 1 |  | claude | — | [US-GCG-17](stories/US-GCG-17.md) |
| [US-GCG-17-6](tasks/US-GCG-17-6.md) | Configure Apple Developer account and iOS provisioning | ✅ done | 2 |  | claude | — | [US-GCG-17](stories/US-GCG-17.md) |
| [US-GCG-17-7](tasks/US-GCG-17-7.md) | Generate Android keystore and configure signing | ✅ done | 1 |  | claude | — | [US-GCG-17](stories/US-GCG-17.md) |
| [US-GCG-17-8](tasks/US-GCG-17-8.md) | Document signing setup and verify release builds | ✅ done | 1 |  | claude | — | [US-GCG-17](stories/US-GCG-17.md) |
| [US-GCG-18-1](tasks/US-GCG-18-1.md) | Test: EF Core migrations project is set up and configured | ✅ done | 1 |  | claude | — | [US-GCG-18](stories/US-GCG-18.md) |
| [US-GCG-18-2](tasks/US-GCG-18-2.md) | Test: Initial migration creates the base schema | ✅ done | 1 |  | claude | — | [US-GCG-18](stories/US-GCG-18.md) |
| [US-GCG-18-3](tasks/US-GCG-18-3.md) | Test: Migrations run automatically on app startup in development | ✅ done | 1 |  | claude | — | [US-GCG-18](stories/US-GCG-18.md) |
| [US-GCG-18-4](tasks/US-GCG-18-4.md) | Test: Migration CLI commands documented (add/apply/rollback) | ✅ done | 1 |  | claude | — | [US-GCG-18](stories/US-GCG-18.md) |
| [US-GCG-18-5](tasks/US-GCG-18-5.md) | Test: Seed data script exists for local development | ✅ done | 1 |  | — | US-GCG-18-9 | [US-GCG-18](stories/US-GCG-18.md) |
| [US-GCG-18-6](tasks/US-GCG-18-6.md) | Test: Production migration strategy documented (manual apply vs auto-migrate) | ✅ done | 1 |  | claude | — | [US-GCG-18](stories/US-GCG-18.md) |
| [US-GCG-18-7](tasks/US-GCG-18-7.md) | Set up EF Core with DbContext and initial configuration | ✅ done | 1 |  | claude | — | [US-GCG-18](stories/US-GCG-18.md) |
| [US-GCG-18-8](tasks/US-GCG-18-8.md) | Create initial migration with event schema | ✅ done | 2 |  | claude | — | [US-GCG-18](stories/US-GCG-18.md) |
| [US-GCG-18-9](tasks/US-GCG-18-9.md) | Create seed data and document migration workflow | ✅ done | 1 |  | claude | — | [US-GCG-18](stories/US-GCG-18.md) |
| [US-GCG-19-1](tasks/US-GCG-19-1.md) | Test: appsettings.json and appsettings.Development.json configured with sensible defaults | ✅ done | 1 |  | claude | — | [US-GCG-19](stories/US-GCG-19.md) |
| [US-GCG-19-2](tasks/US-GCG-19-2.md) | Test: .env.example documents all required environment variables | ✅ done | 1 |  | claude | — | [US-GCG-19](stories/US-GCG-19.md) |
| [US-GCG-19-3](tasks/US-GCG-19-3.md) | Test: Docker Compose passes environment variables to services | ✅ done | 1 |  | claude | — | [US-GCG-19](stories/US-GCG-19.md) |
| [US-GCG-19-4](tasks/US-GCG-19-4.md) | Test: Configuration is strongly typed using IOptions pattern in .NET | ✅ done | 1 |  | claude | — | [US-GCG-19](stories/US-GCG-19.md) |
| [US-GCG-19-5](tasks/US-GCG-19-5.md) | Test: Sensitive values (DB password and Firebase credentials and API keys) are loaded from environment only | ✅ done | 1 |  | claude | — | [US-GCG-19](stories/US-GCG-19.md) |
| [US-GCG-19-6](tasks/US-GCG-19-6.md) | Test: Flutter app reads API base URL from build-time environment config | ✅ done | 1 |  | claude | — | [US-GCG-19](stories/US-GCG-19.md) |
| [US-GCG-19-7](tasks/US-GCG-19-7.md) | Set up .NET strongly-typed configuration with IOptions | ✅ done | 2 |  | claude | — | [US-GCG-19](stories/US-GCG-19.md) |
| [US-GCG-19-8](tasks/US-GCG-19-8.md) | Configure Flutter environment-specific settings | ✅ done | 1 |  | claude | — | [US-GCG-19](stories/US-GCG-19.md) |
| [US-GCG-19-9](tasks/US-GCG-19-9.md) | Create .env.example and Docker Compose env integration | ✅ done | 1 |  | claude | — | [US-GCG-19](stories/US-GCG-19.md) |
| [US-GCG-2-1](tasks/US-GCG-2-1.md) | Test: docker compose up starts PostgreSQL Redis and .NET API | ✅ done | 1 |  | claude | — | [US-GCG-2](stories/US-GCG-2.md) |
| [US-GCG-2-2](tasks/US-GCG-2-2.md) | Test: PostgreSQL is accessible on a standard local port | ✅ done | 1 |  | claude | — | [US-GCG-2](stories/US-GCG-2.md) |
| [US-GCG-2-3](tasks/US-GCG-2-3.md) | Test: Redis is accessible on a standard local port | ✅ done | 1 |  | claude | — | [US-GCG-2](stories/US-GCG-2.md) |
| [US-GCG-2-4](tasks/US-GCG-2-4.md) | Test: .NET API connects to local PostgreSQL and Redis | ✅ done | 2 |  | claude | — | [US-GCG-2](stories/US-GCG-2.md) |
| [US-GCG-2-5](tasks/US-GCG-2-5.md) | Test: Environment variables are documented | ✅ done | 1 |  | claude | — | [US-GCG-2](stories/US-GCG-2.md) |
| [US-GCG-2-6](tasks/US-GCG-2-6.md) | Create docker-compose.yml with PostgreSQL and Redis | ✅ done | 1 |  | claude | — | [US-GCG-2](stories/US-GCG-2.md) |
| [US-GCG-2-7](tasks/US-GCG-2-7.md) | Add .NET API Dockerfile and compose service | ✅ done | 2 |  | claude | US-GCG-2-6 | [US-GCG-2](stories/US-GCG-2.md) |
| [US-GCG-2-8](tasks/US-GCG-2-8.md) | Document environment variables and local setup | ⚪ todo | 1 |  | — | US-GCG-2-6, US-GCG-2-7 | [US-GCG-2](stories/US-GCG-2.md) |
| [US-GCG-20-1](tasks/US-GCG-20-1.md) | Test: ScrapedDuck API endpoints documented with example responses | ✅ done | 2 |  | claude | — | [US-GCG-20](stories/US-GCG-20.md) |
| [US-GCG-20-2](tasks/US-GCG-20-2.md) | Test: Event types identified and catalogued (community day and spotlight hour and raid hour etc) | ✅ done | 1 |  | claude | — | [US-GCG-20](stories/US-GCG-20.md) |
| [US-GCG-20-3](tasks/US-GCG-20-3.md) | Test: Buff/bonus data structure understood and mapped | ✅ done | 1 |  | claude | — | [US-GCG-20](stories/US-GCG-20.md) |
| [US-GCG-20-4](tasks/US-GCG-20-4.md) | Test: Internal event data contract defined as shared DTOs | ✅ done | 2 |  | claude | — | [US-GCG-20](stories/US-GCG-20.md) |
| [US-GCG-20-5](tasks/US-GCG-20-5.md) | Test: Edge cases identified (multi-day events and recurring events and timezone quirks) | ✅ done | 2 |  | claude | — | [US-GCG-20](stories/US-GCG-20.md) |
| [US-GCG-20-6](tasks/US-GCG-20-6.md) | Test: API reliability and rate limits assessed | ✅ done | 2 |  | claude | — | [US-GCG-20](stories/US-GCG-20.md) |
| [US-GCG-20-7](tasks/US-GCG-20-7.md) | Explore ScrapedDuck API and document endpoints | ✅ done | 2 |  | claude | — | [US-GCG-20](stories/US-GCG-20.md) |
| [US-GCG-20-8](tasks/US-GCG-20-8.md) | Define internal event data contract (DTOs) | ✅ done | 2 |  | claude | US-GCG-20-7 | [US-GCG-20](stories/US-GCG-20.md) |
| [US-GCG-21-1](tasks/US-GCG-21-1.md) | Test: Redis client configured and registered in DI | ✅ done | 1 |  | claude | — | [US-GCG-21](stories/US-GCG-21.md) |
| [US-GCG-21-2](tasks/US-GCG-21-2.md) | Test: Cache service implements get/set/invalidate with configurable TTL | ✅ done | 2 |  | claude | — | [US-GCG-21](stories/US-GCG-21.md) |
| [US-GCG-21-3](tasks/US-GCG-21-3.md) | Test: Cache-aside pattern: check Redis then fall back to PostgreSQL | ✅ done | 2 |  | claude | — | [US-GCG-21](stories/US-GCG-21.md) |
| [US-GCG-21-4](tasks/US-GCG-21-4.md) | Test: Cache is refreshed by the ingestion job on each successful fetch | ✅ done | 1 |  | claude | — | [US-GCG-21](stories/US-GCG-21.md) |
| [US-GCG-21-5](tasks/US-GCG-21-5.md) | Test: Cache handles Redis downtime gracefully (falls back to DB without errors) | ✅ done | 2 |  | claude | — | [US-GCG-21](stories/US-GCG-21.md) |
| [US-GCG-21-6](tasks/US-GCG-21-6.md) | Test: Cache keys are namespaced and documented | ✅ done | 1 |  | claude | — | [US-GCG-21](stories/US-GCG-21.md) |
| [US-GCG-21-7](tasks/US-GCG-21-7.md) | Configure Redis client with StackExchange.Redis | ✅ done | 1 |  | claude | — | [US-GCG-21](stories/US-GCG-21.md) |
| [US-GCG-21-8](tasks/US-GCG-21-8.md) | Implement cache service with cache-aside pattern | ✅ done | 2 |  | claude | — | [US-GCG-21](stories/US-GCG-21.md) |
| [US-GCG-21-9](tasks/US-GCG-21-9.md) | Implement Redis graceful fallback on outage | ✅ done | 1 |  | claude | — | [US-GCG-21](stories/US-GCG-21.md) |
| [US-GCG-22-1](tasks/US-GCG-22-1.md) | Test: Backend stores event times with timezone metadata from ScrapedDuck | ✅ done | 1 |  | — | — | [US-GCG-22](stories/US-GCG-22.md) |
| [US-GCG-22-2](tasks/US-GCG-22-2.md) | Test: API responses include timezone-aware timestamps | ✅ done | 2 |  | claude | — | [US-GCG-22](stories/US-GCG-22.md) |
| [US-GCG-22-3](tasks/US-GCG-22-3.md) | Test: Flutter app converts and displays times in device local timezone | ✅ done | 2 |  | claude | — | [US-GCG-22](stories/US-GCG-22.md) |
| [US-GCG-22-4](tasks/US-GCG-22-4.md) | Test: Events that use local time (same wall-clock time everywhere) are handled correctly | ✅ done | 2 |  | claude | — | [US-GCG-22](stories/US-GCG-22.md) |
| [US-GCG-22-5](tasks/US-GCG-22-5.md) | Test: Events with fixed UTC times are converted to local display correctly | ✅ done | 2 |  | claude | — | [US-GCG-22](stories/US-GCG-22.md) |
| [US-GCG-22-6](tasks/US-GCG-22-6.md) | Test: Unit tests cover timezone edge cases (DST transitions and date boundary crossings) | ✅ done | 3 |  | claude | — | [US-GCG-22](stories/US-GCG-22.md) |
| [US-GCG-22-7](tasks/US-GCG-22-7.md) | Implement backend timezone metadata storage and API response format | ✅ done | 2 |  | claude | — | [US-GCG-22](stories/US-GCG-22.md) |
| [US-GCG-22-8](tasks/US-GCG-22-8.md) | Implement Flutter timezone conversion and display | ✅ done | 2 |  | claude | — | [US-GCG-22](stories/US-GCG-22.md) |
| [US-GCG-22-9](tasks/US-GCG-22-9.md) | Write timezone edge case unit tests | ✅ done | 2 |  | claude | US-GCG-22-7, US-GCG-22-8 | [US-GCG-22](stories/US-GCG-22.md) |
| [US-GCG-23-1](tasks/US-GCG-23-1.md) | Test: Upcoming events screen shows events for the next 7 days | ✅ done | 2 |  | claude | — | [US-GCG-23](stories/US-GCG-23.md) |
| [US-GCG-23-2](tasks/US-GCG-23-2.md) | Test: Events are grouped by day with clear date headers | ✅ done | 2 |  | claude | — | [US-GCG-23](stories/US-GCG-23.md) |
| [US-GCG-23-3](tasks/US-GCG-23-3.md) | Test: Multi-day events span correctly across days | ✅ done | 1 |  | claude | — | [US-GCG-23](stories/US-GCG-23.md) |
| [US-GCG-23-4](tasks/US-GCG-23-4.md) | Test: User can scroll through upcoming days | ✅ done | 2 |  | claude | — | [US-GCG-23](stories/US-GCG-23.md) |
| [US-GCG-23-5](tasks/US-GCG-23-5.md) | Test: Each event card shows type badge and key buffs/bonuses | ✅ done | 1 |  | claude | — | [US-GCG-23](stories/US-GCG-23.md) |
| [US-GCG-23-6](tasks/US-GCG-23-6.md) | Test: Navigation between today view and upcoming view is intuitive | ✅ done | 2 |  | claude | — | [US-GCG-23](stories/US-GCG-23.md) |
| [US-GCG-23-7](tasks/US-GCG-23-7.md) | Build upcoming events screen with day grouping | ✅ done | 3 |  | claude | — | [US-GCG-23](stories/US-GCG-23.md) |
| [US-GCG-23-8](tasks/US-GCG-23-8.md) | Add navigation between today and upcoming views | ✅ done | 2 |  | claude | — | [US-GCG-23](stories/US-GCG-23.md) |
| [US-GCG-24-1](tasks/US-GCG-24-1.md) | Test: Filter chips or tabs for event types are available on event list screens | ⚪ todo | 1 |  | — | — | [US-GCG-24](stories/US-GCG-24.md) |
| [US-GCG-24-2](tasks/US-GCG-24-2.md) | Test: Filtering is instant and works on cached data | ⚪ todo | 1 |  | — | — | [US-GCG-24](stories/US-GCG-24.md) |
| [US-GCG-24-3](tasks/US-GCG-24-3.md) | Test: Active filters persist during the session | ⚪ todo | 1 |  | — | — | [US-GCG-24](stories/US-GCG-24.md) |
| [US-GCG-24-4](tasks/US-GCG-24-4.md) | Test: Filter state resets on app relaunch | ✅ done | 1 |  | claude | — | [US-GCG-24](stories/US-GCG-24.md) |
| [US-GCG-24-5](tasks/US-GCG-24-5.md) | Test: Empty state shown when no events match the filter | ✅ done | 1 |  | claude | — | [US-GCG-24](stories/US-GCG-24.md) |
| [US-GCG-24-6](tasks/US-GCG-24-6.md) | Implement event type filter chips | ✅ done | 2 |  | claude | — | [US-GCG-24](stories/US-GCG-24.md) |
| [US-GCG-24-7](tasks/US-GCG-24-7.md) | Add filter state management | ✅ done | 1 |  | claude | — | [US-GCG-24](stories/US-GCG-24.md) |
| [US-GCG-25-1](tasks/US-GCG-25-1.md) | Test: 2-3 screen onboarding carousel on first launch | ⚪ todo | 1 |  | — | — | [US-GCG-25](stories/US-GCG-25.md) |
| [US-GCG-25-2](tasks/US-GCG-25-2.md) | Test: Explains: see today's buffs and flag events and get notified | ⚪ todo | 1 |  | — | — | [US-GCG-25](stories/US-GCG-25.md) |
| [US-GCG-25-3](tasks/US-GCG-25-3.md) | Test: Skip button available on every screen | ✅ done | 1 |  | claude | — | [US-GCG-25](stories/US-GCG-25.md) |
| [US-GCG-25-4](tasks/US-GCG-25-4.md) | Test: Onboarding only shows once (tracked in local storage) | ✅ done | 1 |  | claude | — | [US-GCG-25](stories/US-GCG-25.md) |
| [US-GCG-25-5](tasks/US-GCG-25-5.md) | Test: After onboarding user lands on the daily events view | ✅ done | 1 |  | claude | — | [US-GCG-25](stories/US-GCG-25.md) |
| [US-GCG-25-6](tasks/US-GCG-25-6.md) | Build onboarding carousel screens | ✅ done | 2 |  | claude | — | [US-GCG-25](stories/US-GCG-25.md) |
| [US-GCG-25-7](tasks/US-GCG-25-7.md) | Implement first-launch detection and routing | ✅ done | 1 |  | claude | — | [US-GCG-25](stories/US-GCG-25.md) |
| [US-GCG-26-1](tasks/US-GCG-26-1.md) | Test: Last sync timestamp displayed on the main screen | ✅ done | 1 |  | claude | — | [US-GCG-26](stories/US-GCG-26.md) |
| [US-GCG-26-2](tasks/US-GCG-26-2.md) | Test: Visual indicator when data is stale (older than 1 hour) | ✅ done | 1 |  | claude | — | [US-GCG-26](stories/US-GCG-26.md) |
| [US-GCG-26-3](tasks/US-GCG-26-3.md) | Test: Sync-in-progress indicator during refresh | ✅ done | 1 |  | claude | — | [US-GCG-26](stories/US-GCG-26.md) |
| [US-GCG-26-4](tasks/US-GCG-26-4.md) | Test: Offline mode banner when no network connection | ✅ done | 1 |  | claude | — | [US-GCG-26](stories/US-GCG-26.md) |
| [US-GCG-26-5](tasks/US-GCG-26-5.md) | Test: Manual refresh option available | ✅ done | 1 |  | claude | — | [US-GCG-26](stories/US-GCG-26.md) |
| [US-GCG-26-6](tasks/US-GCG-26-6.md) | Implement data freshness tracking and display | ✅ done | 2 |  | claude | — | [US-GCG-26](stories/US-GCG-26.md) |
| [US-GCG-27-1](tasks/US-GCG-27-1.md) | Test: Loading skeleton or spinner shown while fetching data | ✅ done | 1 |  | claude | — | [US-GCG-27](stories/US-GCG-27.md) |
| [US-GCG-27-2](tasks/US-GCG-27-2.md) | Test: Empty state screen when no events are active today | ✅ done | 1 |  | claude | — | [US-GCG-27](stories/US-GCG-27.md) |
| [US-GCG-27-3](tasks/US-GCG-27-3.md) | Test: Error state screen with retry button on API failure | ✅ done | 1 |  | claude | — | [US-GCG-27](stories/US-GCG-27.md) |
| [US-GCG-27-4](tasks/US-GCG-27-4.md) | Test: Network error state with offline mode explanation | ✅ done | 1 |  | claude | — | [US-GCG-27](stories/US-GCG-27.md) |
| [US-GCG-27-5](tasks/US-GCG-27-5.md) | Test: All states are visually consistent with the app theme | ✅ done | 1 |  | claude | — | [US-GCG-27](stories/US-GCG-27.md) |
| [US-GCG-27-6](tasks/US-GCG-27-6.md) | Build loading skeleton screens | ✅ done | 1 |  | claude | — | [US-GCG-27](stories/US-GCG-27.md) |
| [US-GCG-27-7](tasks/US-GCG-27-7.md) | Build error and empty state screens | ✅ done | 2 |  | claude | — | [US-GCG-27](stories/US-GCG-27.md) |
| [US-GCG-28-1](tasks/US-GCG-28-1.md) | Test: Settings screen accessible from main navigation | ⚪ todo | 1 |  | — | — | [US-GCG-28](stories/US-GCG-28.md) |
| [US-GCG-28-2](tasks/US-GCG-28-2.md) | Test: Toggle to enable/disable all notifications | ⚪ todo | 1 |  | — | — | [US-GCG-28](stories/US-GCG-28.md) |
| [US-GCG-28-3](tasks/US-GCG-28-3.md) | Test: Configurable notification lead time (5 min/15 min/30 min/1 hour before event ends) | ✅ done | 2 |  | claude | — | [US-GCG-28](stories/US-GCG-28.md) |
| [US-GCG-28-4](tasks/US-GCG-28-4.md) | Test: Option to filter which event types trigger notifications | ✅ done | 2 |  | claude | — | [US-GCG-28](stories/US-GCG-28.md) |
| [US-GCG-28-5](tasks/US-GCG-28-5.md) | Test: Settings persist locally and sync to backend | ✅ done | 2 |  | claude | — | [US-GCG-28](stories/US-GCG-28.md) |
| [US-GCG-28-6](tasks/US-GCG-28-6.md) | Test: Settings screen shows current notification permission status with link to system settings | ✅ done | 2 |  | claude | — | [US-GCG-28](stories/US-GCG-28.md) |
| [US-GCG-28-7](tasks/US-GCG-28-7.md) | Build settings screen UI | ✅ done | 2 |  | claude | — | [US-GCG-28](stories/US-GCG-28.md) |
| [US-GCG-28-8](tasks/US-GCG-28-8.md) | Implement settings persistence and backend sync | ✅ done | 2 |  | claude | US-GCG-28-7 | [US-GCG-28](stories/US-GCG-28.md) |
| [US-GCG-29-1](tasks/US-GCG-29-1.md) | Test: Serilog configured with structured JSON output | ✅ done | 1 |  | claude | — | [US-GCG-29](stories/US-GCG-29.md) |
| [US-GCG-29-2](tasks/US-GCG-29-2.md) | Test: Log levels used consistently (Information for business events and Warning for degraded states and Error for fai... | ✅ done | 1 |  | claude | — | [US-GCG-29](stories/US-GCG-29.md) |
| [US-GCG-29-3](tasks/US-GCG-29-3.md) | Test: ScrapedDuck ingestion job logs fetch results with event counts and timing | ✅ done | 1 |  | claude | — | [US-GCG-29](stories/US-GCG-29.md) |
| [US-GCG-29-4](tasks/US-GCG-29-4.md) | Test: API request logging with correlation IDs | ✅ done | 1 |  | claude | — | [US-GCG-29](stories/US-GCG-29.md) |
| [US-GCG-29-5](tasks/US-GCG-29-5.md) | Test: Health check endpoint reports subsystem status (DB and Redis and ScrapedDuck last fetch) | ✅ done | 2 |  | claude | — | [US-GCG-29](stories/US-GCG-29.md) |
| [US-GCG-29-6](tasks/US-GCG-29-6.md) | Test: Logs are viewable in Coolify dashboard | ✅ done | 1 |  | claude | — | [US-GCG-29](stories/US-GCG-29.md) |
| [US-GCG-29-7](tasks/US-GCG-29-7.md) | Configure Serilog with structured JSON logging | ✅ done | 2 |  | claude | — | [US-GCG-29](stories/US-GCG-29.md) |
| [US-GCG-29-8](tasks/US-GCG-29-8.md) | Add observability to ingestion job and health endpoint | ✅ done | 1 |  | claude | US-GCG-29-7 | [US-GCG-29](stories/US-GCG-29.md) |
| [US-GCG-3-1](tasks/US-GCG-3-1.md) | Test: Dockerfile builds the .NET API successfully | ✅ done | 1 |  | claude | — | [US-GCG-3](stories/US-GCG-3.md) |
| [US-GCG-3-2](tasks/US-GCG-3-2.md) | Test: Coolify webhook triggers on push to main | ✅ done | 1 |  | claude | — | [US-GCG-3](stories/US-GCG-3.md) |
| [US-GCG-3-3](tasks/US-GCG-3-3.md) | Test: Container deploys and runs on Coolify infrastructure | ✅ done | 2 |  | claude | — | [US-GCG-3](stories/US-GCG-3.md) |
| [US-GCG-3-4](tasks/US-GCG-3-4.md) | Test: Environment variables configured in Coolify for DB and Redis connections | ✅ done | 1 |  | claude | — | [US-GCG-3](stories/US-GCG-3.md) |
| [US-GCG-3-5](tasks/US-GCG-3-5.md) | Create production Dockerfile for .NET API | ✅ done | 2 |  | claude | — | [US-GCG-3](stories/US-GCG-3.md) |
| [US-GCG-3-6](tasks/US-GCG-3-6.md) | Configure Coolify deployment with GitHub webhook | ✅ done | 2 |  | claude | US-GCG-3-5 | [US-GCG-3](stories/US-GCG-3.md) |
| [US-GCG-30-1](tasks/US-GCG-30-1.md) | Test: xUnit test project created and referenced from solution | ✅ done | 1 |  | claude | — | [US-GCG-30](stories/US-GCG-30.md) |
| [US-GCG-30-2](tasks/US-GCG-30-2.md) | Test: Unit test pattern established with mocking (NSubstitute or Moq) | ✅ done | 2 |  | claude | — | [US-GCG-30](stories/US-GCG-30.md) |
| [US-GCG-30-3](tasks/US-GCG-30-3.md) | Test: Integration test pattern using WebApplicationFactory with Testcontainers for PostgreSQL and Redis | ✅ done | 3 |  | claude | — | [US-GCG-30](stories/US-GCG-30.md) |
| [US-GCG-30-4](tasks/US-GCG-30-4.md) | Test: ScrapedDuck client tests using WireMock or similar for HTTP mocking | ✅ done | 3 |  | claude | — | [US-GCG-30](stories/US-GCG-30.md) |
| [US-GCG-30-5](tasks/US-GCG-30-5.md) | Test: Test data builders or fixtures for common entities | ✅ done | 2 |  | claude | — | [US-GCG-30](stories/US-GCG-30.md) |
| [US-GCG-30-6](tasks/US-GCG-30-6.md) | Test: Tests run via dotnet test and report results clearly | ✅ done | 1 |  | claude | — | [US-GCG-30](stories/US-GCG-30.md) |
| [US-GCG-30-7](tasks/US-GCG-30-7.md) | Set up xUnit test project with mocking framework | ✅ done | 1 |  | claude | — | [US-GCG-30](stories/US-GCG-30.md) |
| [US-GCG-30-8](tasks/US-GCG-30-8.md) | Set up integration test infrastructure with Testcontainers | ✅ done | 3 |  | claude | US-GCG-30-7 | [US-GCG-30](stories/US-GCG-30.md) |
| [US-GCG-30-9](tasks/US-GCG-30-9.md) | Create ScrapedDuck client tests with HTTP mocking | ✅ done | 2 |  | claude | US-GCG-30-7 | [US-GCG-30](stories/US-GCG-30.md) |
| [US-GCG-31-1](tasks/US-GCG-31-1.md) | Test: Unit test pattern established for Dart services and models | ✅ done | 2 |  | claude | — | [US-GCG-31](stories/US-GCG-31.md) |
| [US-GCG-31-2](tasks/US-GCG-31-2.md) | Test: Widget test pattern established for key screens | ✅ done | 2 |  | claude | — | [US-GCG-31](stories/US-GCG-31.md) |
| [US-GCG-31-3](tasks/US-GCG-31-3.md) | Test: Mock API service created for testing without backend | ✅ done | 2 |  | claude | — | [US-GCG-31](stories/US-GCG-31.md) |
| [US-GCG-31-4](tasks/US-GCG-31-4.md) | Test: Test coverage for event data parsing and timezone conversion | ✅ done | 2 |  | claude | — | [US-GCG-31](stories/US-GCG-31.md) |
| [US-GCG-31-5](tasks/US-GCG-31-5.md) | Test: Golden tests for critical UI components (event card and daily view) | ✅ done | 3 |  | claude | — | [US-GCG-31](stories/US-GCG-31.md) |
| [US-GCG-31-6](tasks/US-GCG-31-6.md) | Test: Tests run via flutter test and report results clearly | ✅ done | 1 |  | claude | — | [US-GCG-31](stories/US-GCG-31.md) |
| [US-GCG-31-7](tasks/US-GCG-31-7.md) | Set up Flutter test infrastructure and mock services | ✅ done | 2 |  | claude | — | [US-GCG-31](stories/US-GCG-31.md) |
| [US-GCG-31-8](tasks/US-GCG-31-8.md) | Write unit tests for event models and timezone logic | ✅ done | 2 |  | claude | US-GCG-31-7 | [US-GCG-31](stories/US-GCG-31.md) |
| [US-GCG-31-9](tasks/US-GCG-31-9.md) | Write widget tests for key screens | ✅ done | 2 |  | claude | US-GCG-31-7 | [US-GCG-31](stories/US-GCG-31.md) |
| [US-GCG-32-1](tasks/US-GCG-32-1.md) | Test: GitHub Actions workflow runs on push and PR | ✅ done | 1 |  | claude | — | [US-GCG-32](stories/US-GCG-32.md) |
| [US-GCG-32-2](tasks/US-GCG-32-2.md) | Test: Backend: dotnet format check and dotnet build and dotnet test | ✅ done | 2 |  | claude | — | [US-GCG-32](stories/US-GCG-32.md) |
| [US-GCG-32-3](tasks/US-GCG-32-3.md) | Test: Frontend: dart analyze and flutter test | ✅ done | 2 |  | claude | — | [US-GCG-32](stories/US-GCG-32.md) |
| [US-GCG-32-4](tasks/US-GCG-32-4.md) | Test: Pipeline fails on lint errors or test failures | ✅ done | 1 |  | claude | — | [US-GCG-32](stories/US-GCG-32.md) |
| [US-GCG-32-5](tasks/US-GCG-32-5.md) | Test: Pipeline status badge in README | ✅ done | 1 |  | claude | — | [US-GCG-32](stories/US-GCG-32.md) |
| [US-GCG-32-6](tasks/US-GCG-32-6.md) | Test: Pipeline completes in under 5 minutes | ✅ done | 1 |  | claude | — | [US-GCG-32](stories/US-GCG-32.md) |
| [US-GCG-32-7](tasks/US-GCG-32-7.md) | Create GitHub Actions workflow for .NET backend | ✅ done | 2 |  | claude | — | [US-GCG-32](stories/US-GCG-32.md) |
| [US-GCG-32-8](tasks/US-GCG-32-8.md) | Create GitHub Actions workflow for Flutter app | ✅ done | 2 |  | claude | — | [US-GCG-32](stories/US-GCG-32.md) |
| [US-GCG-32-9](tasks/US-GCG-32-9.md) | Add status badges and pipeline optimisation | ✅ done | 1 |  | claude | US-GCG-32-7, US-GCG-32-8 | [US-GCG-32](stories/US-GCG-32.md) |
| [US-GCG-33-1](tasks/US-GCG-33-1.md) | Test: .editorconfig with consistent settings for both languages | ✅ done | 1 |  | claude | — | [US-GCG-33](stories/US-GCG-33.md) |
| [US-GCG-33-2](tasks/US-GCG-33-2.md) | Test: C# .NET analysers configured (nullable reference types enabled and CA rules) | ⚪ todo | 2 |  | — | US-GCG-33-6 | [US-GCG-33](stories/US-GCG-33.md) |
| [US-GCG-33-3](tasks/US-GCG-33-3.md) | Test: Dart analysis_options.yaml with strict mode and recommended lint rules | ✅ done | 1 |  | claude | — | [US-GCG-33](stories/US-GCG-33.md) |
| [US-GCG-33-4](tasks/US-GCG-33-4.md) | Test: Pre-commit formatting documented (dotnet format and dart format) | ✅ done | 1 |  | claude | — | [US-GCG-33](stories/US-GCG-33.md) |
| [US-GCG-33-5](tasks/US-GCG-33-5.md) | Test: IDE settings files (.vscode or equivalent) for consistent developer experience | ⚪ todo | 1 |  | — | — | [US-GCG-33](stories/US-GCG-33.md) |
| [US-GCG-33-6](tasks/US-GCG-33-6.md) | Configure code quality tooling for both stacks | ✅ done | 2 |  | claude | — | [US-GCG-33](stories/US-GCG-33.md) |
| [US-GCG-34-1](tasks/US-GCG-34-1.md) | Test: API endpoints are versioned (e.g. /api/v1/events) | ✅ done | 1 |  | claude | — | [US-GCG-34](stories/US-GCG-34.md) |
| [US-GCG-34-2](tasks/US-GCG-34-2.md) | Test: Swagger/OpenAPI spec generated from code annotations | ✅ done | 1 |  | claude | — | [US-GCG-34](stories/US-GCG-34.md) |
| [US-GCG-34-3](tasks/US-GCG-34-3.md) | Test: Swagger UI available in development mode | ✅ done | 1 |  | claude | — | [US-GCG-34](stories/US-GCG-34.md) |
| [US-GCG-34-4](tasks/US-GCG-34-4.md) | Test: API response models documented with examples | ✅ done | 1 |  | claude | — | [US-GCG-34](stories/US-GCG-34.md) |
| [US-GCG-34-5](tasks/US-GCG-34-5.md) | Test: Breaking change policy documented | ✅ done | 1 |  | claude | — | [US-GCG-34](stories/US-GCG-34.md) |
| [US-GCG-34-6](tasks/US-GCG-34-6.md) | Implement API versioning with /api/v1/ prefix | ✅ done | 1 |  | claude | — | [US-GCG-34](stories/US-GCG-34.md) |
| [US-GCG-34-7](tasks/US-GCG-34-7.md) | Configure Swagger/OpenAPI documentation | ✅ done | 2 |  | claude | US-GCG-34-6 | [US-GCG-34](stories/US-GCG-34.md) |
| [US-GCG-35-1](tasks/US-GCG-35-1.md) | Test: E2E test verifies: mock ScrapedDuck data is ingested and served via API and displayed in app | ✅ done | 3 |  | claude | — | [US-GCG-35](stories/US-GCG-35.md) |
| [US-GCG-35-2](tasks/US-GCG-35-2.md) | Test: Flutter integration tests run against a local backend | ✅ done | 2 |  | claude | — | [US-GCG-35](stories/US-GCG-35.md) |
| [US-GCG-35-3](tasks/US-GCG-35-3.md) | Test: Test environment spins up via Docker Compose | ✅ done | 2 |  | claude | — | [US-GCG-35](stories/US-GCG-35.md) |
| [US-GCG-35-4](tasks/US-GCG-35-4.md) | Test: Critical user journeys covered: view today's events and flag an event and view upcoming events | ✅ done | 3 |  | claude | — | [US-GCG-35](stories/US-GCG-35.md) |
| [US-GCG-35-5](tasks/US-GCG-35-5.md) | Test: Tests can run in CI | ✅ done | 2 |  | claude | — | [US-GCG-35](stories/US-GCG-35.md) |
| [US-GCG-35-6](tasks/US-GCG-35-6.md) | Create E2E test Docker Compose environment | ✅ done | 2 |  | claude | — | [US-GCG-35](stories/US-GCG-35.md) |
| [US-GCG-35-7](tasks/US-GCG-35-7.md) | Write Flutter integration tests for critical journeys | ✅ done | 3 |  | claude | US-GCG-35-6 | [US-GCG-35](stories/US-GCG-35.md) |
| [US-GCG-36-1](tasks/US-GCG-36-1.md) | Test: ScrapedDuck outage: backend serves cached data from PostgreSQL with degraded status | ✅ done | 2 |  | claude | — | [US-GCG-36](stories/US-GCG-36.md) |
| [US-GCG-36-2](tasks/US-GCG-36-2.md) | Test: Redis outage: API falls back to PostgreSQL queries with no user-visible error | ✅ done | 2 |  | claude | — | [US-GCG-36](stories/US-GCG-36.md) |
| [US-GCG-36-3](tasks/US-GCG-36-3.md) | Test: HTTP client uses retry with exponential backoff for ScrapedDuck calls | ✅ done | 2 |  | claude | — | [US-GCG-36](stories/US-GCG-36.md) |
| [US-GCG-36-4](tasks/US-GCG-36-4.md) | Test: Circuit breaker pattern prevents cascading failures on sustained outages | ✅ done | 2 |  | claude | — | [US-GCG-36](stories/US-GCG-36.md) |
| [US-GCG-36-5](tasks/US-GCG-36-5.md) | Test: Health endpoint reports degraded status when dependencies are down | ✅ done | 2 |  | claude | — | [US-GCG-36](stories/US-GCG-36.md) |
| [US-GCG-36-6](tasks/US-GCG-36-6.md) | Test: Ingestion job alerts on repeated failures (logged at Warning/Error level) | ✅ done | 2 |  | claude | — | [US-GCG-36](stories/US-GCG-36.md) |
| [US-GCG-36-7](tasks/US-GCG-36-7.md) | Implement HTTP retry with Polly for ScrapedDuck client | ✅ done | 2 |  | claude | — | [US-GCG-36](stories/US-GCG-36.md) |
| [US-GCG-36-8](tasks/US-GCG-36-8.md) | Implement graceful degradation in API endpoints | ✅ done | 2 |  | claude | US-GCG-36-7 | [US-GCG-36](stories/US-GCG-36.md) |
| [US-GCG-4-1](tasks/US-GCG-4-1.md) | Test: Background job fetches from ScrapedDuck API on a configurable schedule | ✅ done | 2 |  | claude | — | [US-GCG-4](stories/US-GCG-4.md) |
| [US-GCG-4-2](tasks/US-GCG-4-2.md) | Test: Raw event data is parsed and normalised into a consistent schema | ✅ done | 2 |  | claude | — | [US-GCG-4](stories/US-GCG-4.md) |
| [US-GCG-4-3](tasks/US-GCG-4-3.md) | Test: Events are stored in PostgreSQL with proper fields (title name dates buffs type) | ✅ done | 2 |  | claude | — | [US-GCG-4](stories/US-GCG-4.md) |
| [US-GCG-4-4](tasks/US-GCG-4-4.md) | Test: Summarised event data is cached in Redis | ✅ done | 2 |  | claude | — | [US-GCG-4](stories/US-GCG-4.md) |
| [US-GCG-4-5](tasks/US-GCG-4-5.md) | Test: Job handles ScrapedDuck downtime gracefully by serving cached data | ✅ done | 2 |  | claude | — | [US-GCG-4](stories/US-GCG-4.md) |
| [US-GCG-4-6](tasks/US-GCG-4-6.md) | Test: Job logs success/failure for observability | ✅ done | 2 |  | claude | — | [US-GCG-4](stories/US-GCG-4.md) |
| [US-GCG-4-7](tasks/US-GCG-4-7.md) | Design and create PostgreSQL event schema with EF Core migrations | ✅ done | 2 |  | claude | — | [US-GCG-4](stories/US-GCG-4.md) |
| [US-GCG-4-8](tasks/US-GCG-4-8.md) | Implement ScrapedDuck API client | ✅ done | 3 |  | claude | — | [US-GCG-4](stories/US-GCG-4.md) |
| [US-GCG-4-9](tasks/US-GCG-4-9.md) | Implement scheduled background ingestion job | ✅ done | 3 |  | claude | US-GCG-4-7, US-GCG-4-8 | [US-GCG-4](stories/US-GCG-4.md) |
| [US-GCG-5-1](tasks/US-GCG-5-1.md) | Test: GET endpoint returns today's active events with buffs and bonuses | ✅ done | 2 |  | claude | — | [US-GCG-5](stories/US-GCG-5.md) |
| [US-GCG-5-2](tasks/US-GCG-5-2.md) | Test: GET endpoint returns upcoming events within a configurable window | ✅ done | 2 |  | claude | — | [US-GCG-5](stories/US-GCG-5.md) |
| [US-GCG-5-3](tasks/US-GCG-5-3.md) | Test: Responses are served from Redis cache with PostgreSQL fallback | ✅ done | 2 |  | — | — | [US-GCG-5](stories/US-GCG-5.md) |
| [US-GCG-5-4](tasks/US-GCG-5-4.md) | Test: API returns properly shaped JSON matching the app's data model | ✅ done | 2 |  | claude | — | [US-GCG-5](stories/US-GCG-5.md) |
| [US-GCG-5-5](tasks/US-GCG-5-5.md) | Test: API enforces rate limiting to prevent abuse | ✅ done | 2 |  | claude | — | [US-GCG-5](stories/US-GCG-5.md) |
| [US-GCG-5-6](tasks/US-GCG-5-6.md) | Test: Health check endpoint exists for monitoring | ✅ done | 1 |  | claude | — | [US-GCG-5](stories/US-GCG-5.md) |
| [US-GCG-5-7](tasks/US-GCG-5-7.md) | Implement GET /events/active endpoint | ✅ done | 2 |  | claude | — | [US-GCG-5](stories/US-GCG-5.md) |
| [US-GCG-5-8](tasks/US-GCG-5-8.md) | Implement GET /events/upcoming endpoint | ✅ done | 2 |  | claude | — | [US-GCG-5](stories/US-GCG-5.md) |
| [US-GCG-5-9](tasks/US-GCG-5-9.md) | Add rate limiting and health check endpoint | ✅ done | 1 |  | claude | — | [US-GCG-5](stories/US-GCG-5.md) |
| [US-GCG-6-1](tasks/US-GCG-6-1.md) | Test: App launches on both iOS and Android simulators | ✅ done | 1 |  | — | US-GCG-6-5 | [US-GCG-6](stories/US-GCG-6.md) |
| [US-GCG-6-2](tasks/US-GCG-6-2.md) | Test: Basic app structure with navigation is in place | ✅ done | 1 |  | claude | — | [US-GCG-6](stories/US-GCG-6.md) |
| [US-GCG-6-3](tasks/US-GCG-6-3.md) | Test: App theme and styling foundations established | ✅ done | 1 |  | claude | — | [US-GCG-6](stories/US-GCG-6.md) |
| [US-GCG-6-4](tasks/US-GCG-6-4.md) | Test: API service layer scaffolded for backend communication | ✅ done | 1 |  | claude | — | [US-GCG-6](stories/US-GCG-6.md) |
| [US-GCG-6-5](tasks/US-GCG-6-5.md) | Set up Flutter app structure with state management | ✅ done | 2 |  | claude | — | [US-GCG-6](stories/US-GCG-6.md) |
| [US-GCG-6-6](tasks/US-GCG-6-6.md) | Create API service layer and event data models | ✅ done | 2 |  | claude | — | [US-GCG-6](stories/US-GCG-6.md) |
| [US-GCG-7-1](tasks/US-GCG-7-1.md) | Test: Today's active events are displayed with buff/bonus details | ✅ done | 2 |  | claude | — | [US-GCG-7](stories/US-GCG-7.md) |
| [US-GCG-7-2](tasks/US-GCG-7-2.md) | Test: Events show start and end times in the user's local timezone | ✅ done | 1 |  | claude | — | [US-GCG-7](stories/US-GCG-7.md) |
| [US-GCG-7-3](tasks/US-GCG-7-3.md) | Test: Event types are visually distinct (community day vs spotlight hour vs raid hour etc) | ✅ done | 2 |  | claude | — | [US-GCG-7](stories/US-GCG-7.md) |
| [US-GCG-7-4](tasks/US-GCG-7-4.md) | Test: Active buffs are prominently displayed (2x candy and bonus XP etc) | ✅ done | 2 |  | claude | — | [US-GCG-7](stories/US-GCG-7.md) |
| [US-GCG-7-5](tasks/US-GCG-7-5.md) | Test: Pull-to-refresh updates event data from the API | ✅ done | 2 |  | claude | — | [US-GCG-7](stories/US-GCG-7.md) |
| [US-GCG-7-6](tasks/US-GCG-7-6.md) | Test: Loading and error states are handled gracefully | ✅ done | 2 |  | claude | — | [US-GCG-7](stories/US-GCG-7.md) |
| [US-GCG-7-7](tasks/US-GCG-7-7.md) | Build daily active events screen | ✅ done | 3 |  | claude | — | [US-GCG-7](stories/US-GCG-7.md) |
| [US-GCG-7-8](tasks/US-GCG-7-8.md) | Build event detail view | ✅ done | 2 |  | claude | — | [US-GCG-7](stories/US-GCG-7.md) |
| [US-GCG-7-9](tasks/US-GCG-7-9.md) | Implement event type visual differentiation | ✅ done | 2 |  | claude | — | [US-GCG-7](stories/US-GCG-7.md) |
| [US-GCG-8-1](tasks/US-GCG-8-1.md) | Test: User can tap to flag/unflag any event | ✅ done | 2 |  | claude | — | [US-GCG-8](stories/US-GCG-8.md) |
| [US-GCG-8-2](tasks/US-GCG-8-2.md) | Test: Flagged events are visually distinct in the calendar view | ✅ done | 1 |  | claude | — | [US-GCG-8](stories/US-GCG-8.md) |
| [US-GCG-8-3](tasks/US-GCG-8-3.md) | Test: Flags persist across app restarts using local storage | ✅ done | 1 |  | claude | — | [US-GCG-8](stories/US-GCG-8.md) |
| [US-GCG-8-4](tasks/US-GCG-8-4.md) | Test: Flagged events section or filter is available | ✅ done | 1 |  | claude | — | [US-GCG-8](stories/US-GCG-8.md) |
| [US-GCG-8-5](tasks/US-GCG-8-5.md) | Implement local flag storage with SharedPreferences or Hive | ✅ done | 1 |  | claude | — | [US-GCG-8](stories/US-GCG-8.md) |
| [US-GCG-8-6](tasks/US-GCG-8-6.md) | Add flag toggle UI to event cards and detail view | ✅ done | 2 |  | claude | US-GCG-8-5 | [US-GCG-8](stories/US-GCG-8.md) |
| [US-GCG-9-1](tasks/US-GCG-9-1.md) | Test: Event data is cached locally on the device after each API sync | ✅ done | 2 |  | claude | — | [US-GCG-9](stories/US-GCG-9.md) |
| [US-GCG-9-2](tasks/US-GCG-9-2.md) | Test: App displays cached data when offline | ✅ done | 2 |  | claude | — | [US-GCG-9](stories/US-GCG-9.md) |
| [US-GCG-9-3](tasks/US-GCG-9-3.md) | Test: App indicates when data may be stale due to offline mode | ✅ done | 2 |  | claude | — | [US-GCG-9](stories/US-GCG-9.md) |
| [US-GCG-9-4](tasks/US-GCG-9-4.md) | Test: Data syncs automatically when network connectivity is restored | ✅ done | 2 |  | claude | — | [US-GCG-9](stories/US-GCG-9.md) |
| [US-GCG-9-5](tasks/US-GCG-9-5.md) | Test: Local cache is cleared and refreshed on a reasonable schedule | ✅ done | 1 |  | claude | — | [US-GCG-9](stories/US-GCG-9.md) |
| [US-GCG-9-6](tasks/US-GCG-9-6.md) | Implement local SQLite cache for event data | ✅ done | 2 |  | claude | — | [US-GCG-9](stories/US-GCG-9.md) |
| [US-GCG-9-7](tasks/US-GCG-9-7.md) | Implement offline-first data loading strategy | ✅ done | 3 |  | claude | US-GCG-9-6 | [US-GCG-9](stories/US-GCG-9.md) |
