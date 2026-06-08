import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../repositories/mess_repository.dart';
import '../services/local_notification_service.dart';
import '../theme/app_theme.dart';

class NotificationsButton extends StatelessWidget {
  const NotificationsButton({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MessNotification>>(
      stream: repo.notificationsStream(messId, profile.uid),
      builder: (context, snap) {
        final items = snap.data ?? const <MessNotification>[];
        return IconButton(
          tooltip: 'Notifications',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          iconSize: 22,
          onPressed: () => _open(context),
          icon: items.isEmpty
              ? const Icon(Icons.notifications_none_rounded)
              : Badge(
                  offset: const Offset(4, -4),
                  label: Text('${items.length > 9 ? '9+' : items.length}'),
                  child: const Icon(Icons.notifications_active_rounded),
                ),
        );
      },
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _NotificationsSheet(
        repo: repo,
        messId: messId,
        profile: profile,
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({
    required this.repo,
    required this.messId,
    required this.profile,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: StreamBuilder<List<MessNotification>>(
          stream: repo.notificationsStream(messId, profile.uid),
          builder: (ctx, snap) {
            final items = snap.data ?? const <MessNotification>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          for (final n in items) {
                            await repo.dismissNotification(messId, n.id);
                            LocalNotificationService.instance.forgetSeen(n.id);
                          }
                        },
                        child: const Text('Clear all'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No notifications',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final n = items[i];
                        return ListTile(
                          leading: _kindIcon(n.kind),
                          title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(n.body),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat.MMMd().add_jm().format(
                                      DateTime.fromMillisecondsSinceEpoch(n.createdAt),
                                    ),
                                style: Theme.of(ctx).textTheme.labelSmall,
                              ),
                              IconButton(
                                tooltip: 'Dismiss',
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () async {
                                  await repo.dismissNotification(messId, n.id);
                                  LocalNotificationService.instance.forgetSeen(n.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kindIcon(String kind) {
    switch (kind) {
      case NotificationKinds.chat:
        return const CircleAvatar(child: Icon(Icons.chat_bubble_outline_rounded, size: 18));
      case NotificationKinds.event:
        return const CircleAvatar(child: Icon(Icons.event_outlined, size: 18));
      case NotificationKinds.groceryDuty:
        return const CircleAvatar(child: Icon(Icons.shopping_basket_outlined, size: 18));
      case NotificationKinds.dutySwap:
        return const CircleAvatar(child: Icon(Icons.swap_horiz_rounded, size: 18));
      case NotificationKinds.join:
        return const CircleAvatar(child: Icon(Icons.person_add_alt_1_rounded, size: 18));
      default:
        return const CircleAvatar(child: Icon(Icons.notifications_rounded, size: 18));
    }
  }
}
