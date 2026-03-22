# GoCalGo — Pokemon Go Events Calendar

[![Backend](https://github.com/Biztactix-Ryan/GoCalGo/actions/workflows/backend.yml/badge.svg)](https://github.com/Biztactix-Ryan/GoCalGo/actions/workflows/backend.yml)
[![Flutter](https://github.com/Biztactix-Ryan/GoCalGo/actions/workflows/flutter.yml/badge.svg)](https://github.com/Biztactix-Ryan/GoCalGo/actions/workflows/flutter.yml)

A mobile app for Pokemon Go players that shows a clear, daily view of active event buffs and bonuses. No more digging through scattered announcements — just open the app to see what's boosted today.

## Project Structure

```
src/
  app/          # Flutter mobile app (iOS & Android)
  backend/      # .NET minimal API
docs/           # Project documentation
```

## Prerequisites

- **Flutter** >= 3.27.0 (Dart SDK >= 3.6.0)
- **.NET** 8.0 SDK or later
- **Docker** (optional, for running backend services locally)

## Setup

### Flutter App

```bash
cd src/app
flutter pub get
flutter run
```

### .NET Backend

```bash
cd src/backend
dotnet restore
dotnet run
```

### Backend Services (Docker Compose)

The backend depends on PostgreSQL and Redis. For local development, run them via Docker:

```bash
docker compose up -d
```

## Testing

### Flutter App

Run all tests from the `src/app` directory:

```bash
cd src/app
flutter test
```

This runs unit, widget, and golden tests across the full suite. Output shows each test file with pass/fail status and a summary at the end.

**Run a specific test file:**

```bash
flutter test test/models/buff_test.dart
```

**Run tests with verbose output** (shows each individual test name):

```bash
flutter test --reporter expanded
```

**Update golden files** after intentional UI changes:

```bash
flutter test --update-goldens
```

### Test organisation

```
test/
  config/       # Environment and styling config tests
  models/       # JSON parsing, edge cases for data models
  services/     # API client, caching, offline, timezone logic
  screens/      # Widget tests for full screens + golden tests
  widgets/      # Widget tests for individual components + golden tests
  helpers/      # Shared test utilities, mocks, and test data factories
```

### .NET Backend

```bash
cd src/backend
dotnet test
```

## Code Formatting

Format your code before committing to keep the codebase consistent. The project uses `.editorconfig` for shared editor settings and language-specific formatters for enforcement.

### .NET (C#)

```bash
cd src/backend
dotnet format
```

To check for violations without modifying files (useful in CI):

```bash
dotnet format --verify-no-changes
```

### Flutter (Dart)

```bash
cd src/app
dart format .
```

To check for violations without modifying files:

```bash
dart format --set-exit-if-changed .
```

### Pre-commit Checklist

Before pushing, run both formatters:

```bash
# From repo root
(cd src/backend && dotnet format)
(cd src/app && dart format .)
```

## Database Migrations

The backend uses EF Core migrations with PostgreSQL. All commands run from the `src/backend` directory against the `GoCalGo.Api` project.

**Install the EF Core CLI tool** (one-time):

```bash
dotnet tool install --global dotnet-ef
```

### Add a new migration

After changing entity classes or `GoCalGoDbContext`, create a migration:

```bash
cd src/backend
dotnet ef migrations add <MigrationName> --project GoCalGo.Api
```

### Apply migrations

In development, migrations run automatically on app startup. To apply manually:

```bash
cd src/backend
dotnet ef database update --project GoCalGo.Api
```

### Rollback a migration

Revert to a previous migration by name:

```bash
cd src/backend
dotnet ef database update <PreviousMigrationName> --project GoCalGo.Api
```

To remove the last unapplied migration from code:

```bash
cd src/backend
dotnet ef migrations remove --project GoCalGo.Api
```

### List migrations

```bash
cd src/backend
dotnet ef migrations list --project GoCalGo.Api
```

### Reset the database

Drop and recreate the database by reverting all migrations, then re-applying:

```bash
cd src/backend
dotnet ef database update 0 --project GoCalGo.Api
dotnet ef database update --project GoCalGo.Api
```

### Seed data for local development

A SQL script at `scripts/seed-data.sql` inserts sample Pokemon Go events (Community Day, Spotlight Hour, Raid Hour, multi-day events, GO Battle League, Rocket Takeover, and Season) with associated buffs.

**Run directly with psql:**

```bash
psql -h localhost -U gocalgo -d gocalgo_dev -f scripts/seed-data.sql
```

**Or via Docker Compose:**

```bash
docker compose exec -T postgres psql -U gocalgo -d gocalgo_dev < scripts/seed-data.sql
```

The script is idempotent — it clears existing seed data before inserting.

### Production migration strategy

**Development** — migrations apply automatically on app startup via `Database.Migrate()` in `Program.cs`. This keeps the local database in sync without manual steps.

**Production** — auto-migrate is disabled. Apply migrations manually before deploying a new release:

```bash
cd src/backend
dotnet ef database update --project GoCalGo.Api --connection "<PRODUCTION_CONNECTION_STRING>"
```

Alternatively, generate a SQL script for review before applying:

```bash
dotnet ef migrations script --idempotent --project GoCalGo.Api -o migrate.sql
```

Then apply the script through your preferred database tool (e.g., `psql`, pgAdmin).

**Why manual over auto-migrate in production:**

- Scripts can be reviewed and approved before execution
- Rollback is explicit — you control when and how to revert
- Avoids race conditions when running multiple app instances
- Failed migrations don't block application startup

## App Signing

Signing credentials are required for release builds but must **never** be committed to git. The `.gitignore` excludes keystore files (`*.jks`, `*.keystore`), provisioning profiles (`*.mobileprovision`), certificates (`*.p12`, `*.cer`), and `key.properties`.

### Android

1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore ~/gocalgo-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias gocalgo
   ```
2. Set the environment variables in your `.env` (see `.env.example`):
   - `ANDROID_KEYSTORE_PATH` — absolute path to the `.jks` file
   - `ANDROID_KEYSTORE_PASSWORD` — keystore password
   - `ANDROID_KEY_ALIAS` — key alias (default: `gocalgo`)
   - `ANDROID_KEY_PASSWORD` — key password
3. Copy the key properties template and fill in your values:
   ```bash
   cp src/app/android/key.properties.example src/app/android/key.properties
   ```
   The `build.gradle.kts` loads signing config from `key.properties` automatically when the file exists.
4. Verify the setup:
   ```bash
   bash scripts/test-android-keystore.sh
   ```
5. Build a signed release:
   ```bash
   cd src/app && flutter build appbundle
   ```

### iOS

1. Configure your Apple Developer account with the bundle ID (`com.gocalgo.app`) and create a provisioning profile via Xcode or the [Apple Developer portal](https://developer.apple.com).
2. Set the environment variables in your `.env`:
   - `IOS_TEAM_ID` — Apple Developer Team ID
   - `IOS_CODE_SIGN_IDENTITY` — e.g. `"Apple Distribution: Team Name (XXXXXXXXXX)"`
   - `IOS_PROVISIONING_PROFILE` — provisioning profile name or UUID
3. The signing config is in `src/app/ios/Signing.xcconfig`, which reads these env vars at build time. For local development with automatic signing, comment out the xcconfig lines and enable "Automatically manage signing" in Xcode.
4. Export options plists are provided for both workflows:
   - `src/app/ios/ExportOptions-appstore.plist` — App Store Connect submission
   - `src/app/ios/ExportOptions-development.plist` — development/ad-hoc builds
5. Verify the setup:
   ```bash
   bash scripts/test-ios-signing.sh
   ```
6. Build a signed release:
   ```bash
   cd src/app && flutter build ios --release
   ```

### Credential Security

- Store production signing credentials in a secure vault (e.g., 1Password, CI/CD secrets)
- Never share credentials over unencrypted channels
- Ensure keystore files have restrictive permissions (`chmod 600`)
- For CI/CD, inject credentials as environment variables or secrets — never check them in

## Architecture

- **Flutter App** — UI layer displaying daily event calendar, local event flagging, FCM device token registration
- **.NET Minimal API** — Fetches/caches event data from ScrapedDuck, serves it to the app, schedules push notifications via Firebase Cloud Messaging
- **PostgreSQL** — Persistent storage for cached events, device tokens, and user flags
- **Redis** — In-memory cache for hot event data

See [ARCHITECTURE.md](ARCHITECTURE.md) for full details.

## Deployment

Docker containers managed by Coolify. GitHub webhook on push to `main` triggers automatic build and deploy. See [INFRASTRUCTURE.md](INFRASTRUCTURE.md) for details.
