import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../settings/mess_settings_screen.dart';
import '../../widgets/join_requests_panel.dart';
import '../../widgets/mess_admin_builder.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, required this.repo, required this.messId, required this.profile});

  final MessRepository repo;
  final String messId;
  final UserProfile profile;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  Future<void> _applyRole(Member member, String role) async {
    if (member.uid == widget.profile.uid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ask another admin to change your role.')),
      );
      return;
    }
    try {
      await widget.repo.updateMemberRole(widget.messId, member.uid, role);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.displayName} is now $role')),
      );
    } catch (e) {
      if (!mounted) return;
      showSnackError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + 16;
    final dateFmt = DateFormat.yMMMd();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset),
      child: MessAdminBuilder(
        repo: widget.repo,
        messId: widget.messId,
        profile: widget.profile,
        builder: (context, isAdmin) {
          return StreamBuilder<List<Member>>(
            stream: widget.repo.membersStream(widget.messId),
            builder: (_, snap) {
              final members = snap.data ?? const <Member>[];
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Members',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                          tooltip: 'Admin settings',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MessSettingsScreen(
                                  repo: widget.repo,
                                  messId: widget.messId,
                                  profile: widget.profile,
                                ),
                              ),
                            );
                          },
                          icon: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.primary),
                        ),
                    ],
                  ),
              const SizedBox(height: 4),
              Text(
                'Admins approve join requests; new members only share expenses after they join.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (isAdmin)
                JoinRequestsPanel(
                  repo: widget.repo,
                  messId: widget.messId,
                  adminUid: widget.profile.uid,
                ),
              Expanded(
                child: ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (_, _) => Divider(height: 18, thickness: 0.6, color: Colors.grey.shade200),
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final isSelf = m.uid == widget.profile.uid;
                    final joinedLabel = DateTime.fromMillisecondsSinceEpoch(m.joinedAt);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        child: Text(
                          m.displayName.isEmpty ? '?' : m.displayName.characters.first.toUpperCase(),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          if (isSelf)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Chip(
                                label: const Text('You'),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text('Joined • ${dateFmt.format(joinedLabel)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(m.role.toUpperCase()),
                            backgroundColor:
                                m.role == Roles.admin
                                    ? Theme.of(context).colorScheme.primary
                                    : AppColors.surface,
                            labelStyle: TextStyle(
                              color:
                                  m.role == Roles.admin ? Colors.white : AppColors.onSurface,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (isAdmin)
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'admin') await _applyRole(m, Roles.admin);
                                if (value == 'member') await _applyRole(m, Roles.member);
                              },
                              itemBuilder:
                                  (_) => const [
                                    PopupMenuItem(value: 'admin', child: Text('Make admin')),
                                    PopupMenuItem(value: 'member', child: Text('Make member')),
                                  ],
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
          );
        },
      ),
    );
  }
}
