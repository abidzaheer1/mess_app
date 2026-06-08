import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../repositories/mess_repository.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/expenses/add_expense_screen.dart';

/// Persistent add-expense + chat FABs shown on every main tab.
class ShellActionFabs extends StatelessWidget {
  const ShellActionFabs({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;

  void _openAddExpense(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddExpenseScreen(
          repo: repo,
          messId: messId,
          profile: profile,
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          repo: repo,
          messId: messId,
          profile: profile,
        ),
      ),
    ).then((_) {
      repo.markMessChatRead(messId, profile.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: repo.unreadMessChatCountStream(messId, profile.uid),
      builder: (context, unreadSnap) {
        final unread = unreadSnap.data ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'shell-chat-fab',
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
              onPressed: () => _openChat(context),
              child: unread > 0
                  ? Badge(
                      label: Text(unread > 9 ? '9+' : '$unread'),
                      child: const Icon(Icons.chat_bubble_rounded),
                    )
                  : const Icon(Icons.chat_bubble_rounded),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'shell-add-expense-fab',
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () => _openAddExpense(context),
              child: const Icon(Icons.add_rounded),
            ),
          ],
        );
      },
    );
  }
}
