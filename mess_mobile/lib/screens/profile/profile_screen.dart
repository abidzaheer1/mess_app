import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../session/session_scope.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mess_admin_builder.dart';
import '../settings/mess_settings_screen.dart';
import '../../widgets/mess_invite_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.repo, required this.profile});

  final MessRepository repo;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final liveProfile = SessionScope.maybeOf(context)?.profile ?? profile;
    final messId = liveProfile.messId;
    final bottomInset = MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + 24;

    if (messId == null) {
      return _AccountBody(
        repo: repo,
        profile: liveProfile,
        messName: 'Mess',
        inviteCode: '',
        bottomInset: bottomInset,
        isAdmin: false,
      );
    }

    return MessAdminBuilder(
      repo: repo,
      messId: messId,
      profile: liveProfile,
      builder: (context, isAdmin) {
        return StreamBuilder<Mess?>(
          stream: repo.messStream(messId),
          builder: (_, snap) {
            return _AccountBody(
              repo: repo,
              profile: liveProfile,
              messName: snap.data?.name ?? 'Mess',
              inviteCode: snap.data?.inviteCode ?? '',
              bottomInset: bottomInset,
              isAdmin: isAdmin,
              messId: messId,
            );
          },
        );
      },
    );
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({
    required this.repo,
    required this.profile,
    required this.messName,
    required this.inviteCode,
    required this.bottomInset,
    required this.isAdmin,
    this.messId,
  });

  final MessRepository repo;
  final UserProfile profile;
  final String messName;
  final String inviteCode;
  final double bottomInset;
  final bool isAdmin;
  final String? messId;

  void _openMessSettings(BuildContext context) {
    if (messId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MessSettingsScreen(
          repo: repo,
          messId: messId!,
          profile: profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = profile.displayName.trim().isEmpty
        ? '?'
        : profile.displayName.trim().characters.first.toUpperCase();

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset),
      children: [
        Text(
          'Profile',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryDark,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(profile.email),
                      const SizedBox(height: 10),
                      Text('Mess • $messName'),
                      Text(
                        'Role • ${profile.role ?? 'member'}'.toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (messId != null && inviteCode.isNotEmpty) ...[
          const SizedBox(height: 14),
          MessInviteCard(inviteCode: inviteCode),
        ],
        if (isAdmin && messId != null) ...[
          const SizedBox(height: 14),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openMessSettings(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_rounded, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mess settings',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Admin settings — currency, invite code, rotation',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.tonal(
          onPressed: repo.signOut,
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
