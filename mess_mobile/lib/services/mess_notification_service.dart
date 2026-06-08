import 'dart:async';

import '../models/app_models.dart';
import '../repositories/mess_repository.dart';
import 'local_notification_service.dart';

/// Spark-plan notifications: Firestore stream → local / browser alerts.
/// No Cloud Functions or FCM server required.
class MessNotificationService {
  MessNotificationService._();
  static final instance = MessNotificationService._();

  StreamSubscription<List<MessNotification>>? _sub;
  final Set<String> _knownIds = {};
  var _primed = false;
  String? _activeMessId;
  String? _activeUid;

  void start(MessRepository repo, String messId, String uid) {
    if (_activeMessId == messId && _activeUid == uid && _sub != null) return;
    stop();
    _activeMessId = messId;
    _activeUid = uid;
    _sub = repo.notificationsStream(messId, uid).listen(
      _onNotifications,
      onError: (_) {},
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _knownIds.clear();
    _primed = false;
    _activeMessId = null;
    _activeUid = null;
  }

  void _onNotifications(List<MessNotification> items) {
    if (!_primed) {
      _knownIds.addAll(items.map((n) => n.id));
      _primed = true;
      return;
    }

    for (final n in items) {
      if (_knownIds.contains(n.id)) continue;
      _knownIds.add(n.id);
      unawaited(
        LocalNotificationService.instance.showAlert(
          id: n.id,
          title: n.title,
          body: n.body,
        ),
      );
    }

    _knownIds.removeWhere((id) => !items.any((n) => n.id == id));
  }
}
