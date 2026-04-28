import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShortsStats {
  const ShortsStats({
    required this.attemptsToday,
    required this.blocksToday,
    required this.limitExceeded,
  });

  final int attemptsToday;
  final int blocksToday;
  final bool limitExceeded;

  factory ShortsStats.empty() =>
      const ShortsStats(attemptsToday: 0, blocksToday: 0, limitExceeded: false);

  factory ShortsStats.fromMap(Map<dynamic, dynamic> map) {
    return ShortsStats(
      attemptsToday: (map['attempts_today'] as num?)?.toInt() ?? 0,
      blocksToday: (map['blocks_today'] as num?)?.toInt() ?? 0,
      limitExceeded: map['limit_exceeded'] as bool? ?? false,
    );
  }
}

class PlatformBridge {
  PlatformBridge._();

  static const MethodChannel _methodChannel =
      MethodChannel('shorts_blocker/methods');
  static const EventChannel _eventChannel =
      EventChannel('shorts_blocker/stats_events');

  static final ValueNotifier<bool> blockingEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<ShortsStats> stats =
      ValueNotifier<ShortsStats>(ShortsStats.empty());
    static final ValueNotifier<List<String>> logs =
      ValueNotifier<List<String>>(<String>[]);
  static final ValueNotifier<bool> accessibilityEnabled =
      ValueNotifier<bool>(false);
  static final ValueNotifier<bool> overlayPermissionGranted =
      ValueNotifier<bool>(false);

  static StreamSubscription<dynamic>? _statsSubscription;

  static Future<void> initialize() async {
    await Future.wait<void>([
      refreshBlockingEnabled(),
      refreshStats(),
      refreshLogs(),
      refreshPermissions(),
    ]);

    _statsSubscription ??=
        _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        stats.value = ShortsStats.fromMap(event);
        refreshLogs();
      }
    });
  }

  static Future<void> dispose() async {
    await _statsSubscription?.cancel();
    _statsSubscription = null;
  }

  static Future<void> refreshBlockingEnabled() async {
    final enabled =
        await _methodChannel.invokeMethod<bool>('getBlockingEnabled') ?? true;
    blockingEnabled.value = enabled;
  }

  static Future<void> setBlockingEnabled(bool enabled) async {
    await _methodChannel.invokeMethod<void>('setBlockingEnabled', {
      'enabled': enabled,
    });
    blockingEnabled.value = enabled;
  }

  static Future<void> openAccessibilitySettings() async {
    await _methodChannel.invokeMethod<void>('openAccessibilitySettings');
  }

  static Future<void> openOverlaySettings() async {
    await _methodChannel.invokeMethod<void>('openOverlaySettings');
  }

  static Future<void> refreshStats() async {
    final map = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'getStats',
    );
    if (map != null) {
      stats.value = ShortsStats.fromMap(map);
    }
  }

  static Future<void> refreshLogs() async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>('getLogs');
    if (result == null) {
      logs.value = <String>[];
      return;
    }
    logs.value = result.map((entry) => entry.toString()).toList();
  }

  static Future<void> refreshPermissions() async {
    final isAccessibilityEnabled =
        await _methodChannel.invokeMethod<bool>('isAccessibilityEnabled') ??
            false;
    final isOverlayGranted =
        await _methodChannel.invokeMethod<bool>('isOverlayPermissionGranted') ??
            false;

    accessibilityEnabled.value = isAccessibilityEnabled;
    overlayPermissionGranted.value = isOverlayGranted;
  }
}
