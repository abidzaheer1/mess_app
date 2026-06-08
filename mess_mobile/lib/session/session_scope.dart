import 'package:flutter/material.dart';

import '../models/app_models.dart';

/// Live user profile from Firestore — rebuilds descendants when it changes.
class SessionScope extends InheritedWidget {
  const SessionScope({
    super.key,
    required this.profile,
    required super.child,
  });

  final UserProfile profile;

  static SessionScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope not found above $context');
    return scope!;
  }

  static SessionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionScope>();
  }

  @override
  bool updateShouldNotify(SessionScope oldWidget) {
    final a = oldWidget.profile;
    final b = profile;
    return a.uid != b.uid ||
        a.email != b.email ||
        a.displayName != b.displayName ||
        a.messId != b.messId ||
        a.role != b.role ||
        a.profileComplete != b.profileComplete ||
        a.phone != b.phone ||
        a.dateOfBirth != b.dateOfBirth;
  }
}
