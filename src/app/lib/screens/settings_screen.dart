import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/event_type_style.dart';
import '../models/event_type.dart';
import '../providers/notification_settings_provider.dart';
import '../services/notification_settings_store.dart';

/// Notification permission status as reported by the OS.
enum PermissionStatus { granted, denied, notDetermined }

/// Settings screen for notification preferences.
///
/// Provides:
/// - Master notification toggle
/// - Lead time picker (5/15/30/60 min before event ends)
/// - Event type notification filters
/// - Notification permission status with link to system settings
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.onOpenSystemSettings});

  /// Callback invoked when the user taps "Open Settings" to navigate
  /// to OS notification settings. Defaults to a no-op if not provided.
  final VoidCallback? onOpenSystemSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load settings')),
        data: (settings) => _SettingsBody(
          settings: settings,
          onOpenSystemSettings: onOpenSystemSettings,
        ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({
    required this.settings,
    this.onOpenSystemSettings,
  });

  final NotificationSettings settings;
  final VoidCallback? onOpenSystemSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        // Notification permission status
        _NotificationPermissionStatus(
          status: PermissionStatus.notDetermined,
          onOpenSettings: onOpenSystemSettings ?? () {},
        ),
        const Divider(),

        // Master toggle
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Enable notifications'),
          subtitle: const Text('Receive alerts before events end'),
          value: settings.enabled,
          onChanged: (value) {
            ref.read(notificationSettingsProvider.notifier).saveSettings(
                  settings.copyWith(enabled: value),
                );
          },
        ),
        const Divider(),

        // Lead time picker
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Notify me',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        ...NotificationSettings.allowedLeadTimes.map(
          (minutes) => RadioListTile<int>(
            title: Text(_leadTimeLabel(minutes)),
            value: minutes,
            groupValue: settings.leadTimeMinutes,
            onChanged: settings.enabled
                ? (value) {
                    if (value != null) {
                      ref.read(notificationSettingsProvider.notifier).saveSettings(
                            settings.copyWith(leadTimeMinutes: value),
                          );
                    }
                  }
                : null,
          ),
        ),
        const Divider(),

        // Event type filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Notify me about',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        for (final type in EventType.values)
          _buildEventTypeTile(ref, type, settings),
      ],
    );
  }

  Widget _buildEventTypeTile(
    WidgetRef ref,
    EventType type,
    NotificationSettings settings,
  ) {
    final style = EventTypeStyle.of(type);
    final enabled = settings.enabledEventTypes.contains(type);

    return SwitchListTile(
      secondary: Icon(style.icon, color: style.color),
      title: Text(style.label),
      value: enabled,
      onChanged: settings.enabled
          ? (value) {
              final updatedTypes = Set<EventType>.of(settings.enabledEventTypes);
              if (value) {
                updatedTypes.add(type);
              } else {
                updatedTypes.remove(type);
              }
              ref.read(notificationSettingsProvider.notifier).saveSettings(
                    settings.copyWith(enabledEventTypes: updatedTypes),
                  );
            }
          : null,
    );
  }

  String _leadTimeLabel(int minutes) {
    if (minutes >= 60) {
      return '${minutes ~/ 60} hour before event ends';
    }
    return '$minutes min before event ends';
  }
}

/// Displays the current OS notification permission status with a link
/// to open system settings.
class _NotificationPermissionStatus extends StatelessWidget {
  const _NotificationPermissionStatus({
    required this.status,
    required this.onOpenSettings,
  });

  final PermissionStatus status;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(_iconForStatus(status), color: _colorForStatus(status)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _labelForStatus(status),
                  style: TextStyle(
                    fontSize: 14,
                    color: _colorForStatus(status),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  static IconData _iconForStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Icons.check_circle_outline;
      case PermissionStatus.denied:
        return Icons.warning_amber_rounded;
      case PermissionStatus.notDetermined:
        return Icons.info_outline;
    }
  }

  static Color _colorForStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.red;
      case PermissionStatus.notDetermined:
        return Colors.orange;
    }
  }

  static String _labelForStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Allowed';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.notDetermined:
        return 'Not determined';
    }
  }
}
