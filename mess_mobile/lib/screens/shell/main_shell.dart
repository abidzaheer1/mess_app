import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../events/events_screen.dart';
import '../expenses/expenses_screen.dart';
import '../members/members_screen.dart';
import '../profile/profile_screen.dart';
import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../session/session_scope.dart';
import '../../utils/mess_access.dart';
import '../../widgets/admin_join_notification.dart';
import '../../widgets/join_requests_panel.dart';
import '../../widgets/shell_action_fabs.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.repo});

  final MessRepository repo;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;
  String? _retentionRunFor;

  void _maybeRunRetention(String messId) {
    if (_retentionRunFor == messId) return;
    _retentionRunFor = messId;
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      widget.repo.runRetentionCleanup(messId);
      widget.repo.maybeAdvanceRotation(messId);
    });
  }

  void _openJoinRequests(String messId, UserProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: JoinRequestsPanel(
            repo: widget.repo,
            messId: messId,
            adminUid: profile.uid,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = SessionScope.of(context).profile;
    final messId = profile.messId;
    if (messId == null) {
      return const Scaffold(body: Center(child: Text('No mess linked')));
    }

    _maybeRunRetention(messId);

    final tabs = <Widget>[
      DashboardScreen(
        repo: widget.repo,
        messId: messId,
        profile: profile,
        onOpenMembers: () => setState(() => _index = 3),
      ),
      ExpensesScreen(repo: widget.repo, messId: messId, profile: profile),
      EventsScreen(repo: widget.repo, messId: messId, profile: profile),
      MembersScreen(repo: widget.repo, messId: messId, profile: profile),
      ProfileScreen(repo: widget.repo, profile: profile),
    ];

    return StreamBuilder<Member?>(
      stream: widget.repo.memberStream(messId, profile.uid),
      builder: (context, memberSnap) {
        final member = memberSnap.data;
        final isAdmin = isMessAdmin(uid: profile.uid, profile: profile, member: member);

        return Scaffold(
          body: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Offstage(offstage: i != _index, child: tabs[i]),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.grid_view_rounded),
                  label: 'Dashboard',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.payments_outlined),
                  label: 'Expenses',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  label: 'Events',
                ),
                NavigationDestination(
                  icon: AdminJoinRequestBadge(
                    repo: widget.repo,
                    messId: messId,
                    profile: profile,
                    member: member,
                    child: const Icon(Icons.groups_2_outlined),
                  ),
                  label: 'Members',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  label: 'Profile',
                ),
              ],
            ),
            floatingActionButton: _buildFab(messId, profile, isAdmin),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          );
      },
    );
  }

  Widget _buildFab(String messId, UserProfile profile, bool isAdmin) {
    if (_index == 3 && isAdmin) {
      return StreamBuilder<int>(
        stream: widget.repo.pendingJoinRequestCountStream(messId),
        builder: (context, countSnap) {
          final count = countSnap.data ?? 0;
          if (count <= 0) {
            return ShellActionFabs(
              repo: widget.repo,
              messId: messId,
              profile: profile,
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'shell-join-fab',
                onPressed: () => _openJoinRequests(messId, profile),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text('$count join request${count == 1 ? '' : 's'}'),
              ),
              const SizedBox(height: 12),
              ShellActionFabs(
                repo: widget.repo,
                messId: messId,
                profile: profile,
              ),
            ],
          );
        },
      );
    }
    return ShellActionFabs(
      repo: widget.repo,
      messId: messId,
      profile: profile,
    );
  }
}
