# Security — Pokemon Go Events Calendar

## Authentication
No user authentication at launch. The app operates anonymously — users do not create accounts or log in. Device identity is established via Firebase Cloud Messaging device tokens, which are used solely for push notification delivery.

Authentication may be added in a future phase if user accounts, cross-device sync, or social features are introduced.

## Authorization
No authorization model required at launch. All event data is public and read-only. The only user-specific data is event flags and FCM tokens, which are scoped to the device.

## Data Classification
Low sensitivity. The application handles:
- **Public data:** Pokemon Go event schedules sourced from ScrapedDuck/LeekDuck
- **Device tokens:** FCM registration tokens for push notification delivery — not personally identifiable on their own
- **User preferences:** Event flags indicating which events a user wants notifications for

No PII, no financial data, no health data. No user-submitted content.

## Compliance
None identified. The app does not collect personally identifiable information. If analytics or user accounts are added later, Australian Privacy Act obligations should be reassessed.

## Secret Management
TBD — Coolify environment variables for API keys (Firebase service account credentials, database connection strings). No vault or dedicated secret management tool planned at this stage.

## Threat Model
- **ScrapedDuck API availability:** The event data source is a community project and could go down or change format without notice. The Redis cache and PostgreSQL store provide resilience against short outages. A fallback or manual data entry path may be needed long-term.
- **FCM token abuse:** The backend should validate that incoming token registrations are legitimate to prevent spam or token stuffing.
- **API rate limiting:** The .NET API should enforce rate limits to prevent abuse, especially on endpoints that trigger push notifications or heavy data fetches.
- **No authentication surface:** With no login system, the attack surface is minimal. The main risk is abuse of public API endpoints.

## Security Tooling
None planned at this stage. Dependency scanning (e.g. `dotnet audit`, Flutter pub audit) should be run periodically.
