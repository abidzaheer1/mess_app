import 'package:flutter/material.dart';

import '../repositories/mess_repository.dart';
import '../services/mess_notification_service.dart';

/// Keeps a Firestore notification listener alive for the signed-in mess session.
class LiveNotificationScope extends StatefulWidget {
  const LiveNotificationScope({
    super.key,
    required this.repo,
    required this.messId,
    required this.uid,
    required this.child,
  });

  final MessRepository repo;
  final String messId;
  final String uid;
  final Widget child;

  @override
  State<LiveNotificationScope> createState() => _LiveNotificationScopeState();
}

class _LiveNotificationScopeState extends State<LiveNotificationScope> {
  @override
  void initState() {
    super.initState();
    MessNotificationService.instance.start(widget.repo, widget.messId, widget.uid);
  }

  @override
  void didUpdateWidget(LiveNotificationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messId != widget.messId || oldWidget.uid != widget.uid) {
      MessNotificationService.instance.start(widget.repo, widget.messId, widget.uid);
    }
  }

  @override
  void dispose() {
    MessNotificationService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
