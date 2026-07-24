import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper over flutter_local_notifications for "new chapters" alerts.
/// Fire-and-forget like [WidgetService]; every method swallows its errors so
/// a notification failure never breaks a library refresh.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'releases';
  static const _channelName = 'New chapter releases';

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      // Android 13+ runtime permission; no-op on older versions.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (e) {
      debugPrint('Notifications.init failed: $e');
    }
  }

  /// [notificationId] should be stable per series so re-notifying the same
  /// series replaces the old alert rather than stacking duplicates.
  static Future<void> showNewChapters({
    required int notificationId,
    required String seriesName,
    required num from,
    required num to,
    required int newCount,
  }) async {
    try {
      await init();
      await _plugin.show(
        notificationId,
        seriesName,
        '$newCount new chapter${newCount == 1 ? '' : 's'} '
        '(${_fmt(from)} → ${_fmt(to)})',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Alerts when new chapters are released',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Notifications.showNewChapters failed: $e');
    }
  }

  static String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}
