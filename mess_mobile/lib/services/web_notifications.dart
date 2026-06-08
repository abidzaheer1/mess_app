import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> requestWebNotificationPermission() async {
  if (web.Notification.permission == 'granted') return true;
  if (web.Notification.permission == 'denied') return false;
  final result = (await web.Notification.requestPermission().toDart).toDart;
  return result == 'granted';
}

void showWebNotification({required String title, required String body}) {
  if (web.Notification.permission != 'granted') return;
  web.Notification(title, web.NotificationOptions(body: body));
}
