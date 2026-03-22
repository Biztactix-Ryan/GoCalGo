import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event_type.dart';

/// Shared filter state for event type selection across all screens.
///
/// Empty set means "show all". Lives in memory only — resets on app relaunch
/// when the [ProviderScope] is recreated.
final selectedEventTypesProvider = StateProvider<Set<EventType>>((ref) => {});
