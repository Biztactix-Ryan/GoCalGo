import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/device_token_service.dart';
import '../services/notification_settings_store.dart';
import '../services/notification_settings_sync_service.dart';
import '../services/sqlite_notification_settings_store.dart';

/// Singleton API client used for backend communication.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

/// Singleton notification settings store.
final notificationSettingsStoreProvider =
    Provider<NotificationSettingsStore>((ref) {
  final store = SqliteNotificationSettingsStore();
  ref.onDispose(() => store.close());
  return store;
});

/// Singleton sync service for pushing settings to the backend.
final notificationSettingsSyncServiceProvider =
    Provider<NotificationSettingsSyncService>((ref) {
  return NotificationSettingsSyncService(
    apiClient: ref.read(apiClientProvider),
    deviceTokenService: ref.read(deviceTokenServiceProvider),
  );
});

/// Provides the current notification settings, loaded from local storage.
final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);

/// Manages notification settings state with local persistence and backend sync.
class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() async {
    final store = ref.read(notificationSettingsStoreProvider);
    return store.load();
  }

  /// Updates the settings locally and syncs to backend.
  ///
  /// Local save happens first and is always applied. Backend sync is
  /// fire-and-forget — failures are retried but do not block the UI.
  Future<void> saveSettings(NotificationSettings settings) async {
    final store = ref.read(notificationSettingsStoreProvider);
    await store.save(settings);
    state = AsyncData(settings);

    // Fire-and-forget backend sync
    final syncService = ref.read(notificationSettingsSyncServiceProvider);
    syncService.sync(settings);
  }
}
