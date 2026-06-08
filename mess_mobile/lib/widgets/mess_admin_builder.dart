import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../repositories/mess_repository.dart';
import '../utils/mess_access.dart';

/// Resolves admin access from member doc, user profile role, and mess creator.
class MessAdminBuilder extends StatelessWidget {
  const MessAdminBuilder({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
    required this.builder,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;
  final Widget Function(BuildContext context, bool isAdmin) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Mess?>(
      stream: repo.messStream(messId),
      builder: (context, messSnap) {
        return StreamBuilder<Member?>(
          stream: repo.memberStream(messId, profile.uid),
          builder: (context, memberSnap) {
            final admin = isMessAdmin(
              uid: profile.uid,
              profile: profile,
              member: memberSnap.data,
              mess: messSnap.data,
            );
            return builder(context, admin);
          },
        );
      },
    );
  }
}
