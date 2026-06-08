import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'web_notifications_stub.dart'
    if (dart.library.js_interop) 'web_notifications.dart';

/// Local / browser alerts when new Firestore notification docs arrive.
class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  var _initialized = false;
  final Set<String> _seenIds = {};

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      await requestWebNotificationPermission();
      _initialized = true;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'mess_alerts',
            'Mess alerts',
            description: 'New mess activity',
            importance: Importance.high,
          ),
        );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> showAlert({
    required String id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    if (_seenIds.contains(id)) return;
    _seenIds.add(id);

    if (kIsWeb) {
      showWebNotification(title: title, body: body);
      return;
    }

    await _plugin.show(
      id.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mess_alerts',
          'Mess alerts',
          channelDescription: 'New mess activity',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  void forgetSeen(String id) => _seenIds.remove(id);
}
