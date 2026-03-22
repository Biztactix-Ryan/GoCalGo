/// Configuration for integration tests running against the local backend.
///
/// The backend is expected to be running via Docker Compose:
/// ```
/// docker compose up -d
/// ```
///
/// The API base URL can be overridden via the `INTEGRATION_TEST_API_URL`
/// environment variable for CI or non-standard setups.
class BackendConfig {
  const BackendConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'INTEGRATION_TEST_API_URL',
    defaultValue: 'http://localhost:5000',
  );

  /// The versioned API prefix used by backend endpoints.
  static String get apiV1Url => '$apiBaseUrl/api/v1';
}
