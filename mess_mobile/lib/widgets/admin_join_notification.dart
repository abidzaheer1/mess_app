import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../repositories/mess_repository.dart';
import '../utils/mess_access.dart';
import 'join_requests_panel.dart';

/// Badge overlay when there are pending join requests for an admin.
class AdminJoinRequestBadge extends StatelessWidget {
  const AdminJoinRequestBadge({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
    required this.member,
    required this.child,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;
  final Member? member;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isAdmin = isMessAdmin(
      uid: profile.uid,
      profile: profile,
      member: member,
    );
    if (!isAdmin) return child;

    return StreamBuilder<int>(
      stream: repo.pendingJoinRequestCountStream(messId),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (count <= 0) return child;
        return Badge(
          offset: const Offset(4, -4),
          label: Text('$count'),
          child: child,
        );
      },
    );
  }
}

void showAdminJoinRequestsSheet(
  BuildContext context, {
  required MessRepository repo,
  required String messId,
  required String adminUid,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join requests',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              JoinRequestsPanel(
                repo: repo,
                messId: messId,
                adminUid: adminUid,
              ),
            ],
          ),
        ),
      );
    },
  );
}
