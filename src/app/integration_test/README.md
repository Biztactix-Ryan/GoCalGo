# Integration Tests

Flutter integration tests that run against the local backend.

## Prerequisites

Start the backend services via Docker Compose from the project root:

```bash
docker compose up -d
```

Wait for the API to be healthy:

```bash
curl http://localhost:5000/health
```

## Running

### On a device or emulator

```bash
cd src/app
flutter test integration_test/
```

### Specific test file

```bash
flutter test integration_test/api_client_test.dart
flutter test integration_test/app_test.dart
```

### Custom backend URL

Override the backend URL at build time (e.g. for CI or remote backends):

```bash
flutter test integration_test/ --dart-define=INTEGRATION_TEST_API_URL=http://10.0.2.2:5000
```

> **Note:** Android emulators use `10.0.2.2` to reach the host machine's
> `localhost`. iOS simulators use `localhost` directly.

## Test files

| File | What it tests |
|------|---------------|
| `api_client_test.dart` | API client ↔ backend communication: health check, events endpoints, deserialization |
| `app_test.dart` | Full app launch: home screen renders, navigation works, events load from backend |
