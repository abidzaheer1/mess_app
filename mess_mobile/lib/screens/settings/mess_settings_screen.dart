import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/common.dart';
import '../../widgets/mess_admin_builder.dart';
import '../../session/session_scope.dart';

class MessSettingsScreen extends StatefulWidget {
  const MessSettingsScreen({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
    this.embedded = false,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;

  /// When true, shown inside the bottom-nav shell (no nested app bar).
  final bool embedded;

  @override
  State<MessSettingsScreen> createState() => _MessSettingsScreenState();
}

class _MessSettingsScreenState extends State<MessSettingsScreen> {
  final _nameCtrl = TextEditingController();
  var _currency = defaultMessCurrency;
  var _rotationCycle = 'weekly';
  var _rotationUids = <String>[];
  var _generalBusy = false;
  var _inviteBusy = false;
  var _rotationBusy = false;
  var _generalDirty = false;
  var _rotationDirty = false;
  String? _remoteSyncKey;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  List<String> _rotationFromMess(Mess mess, List<Member> members) {
    if (mess.rotationOrder.isNotEmpty) {
      final known = members.map((m) => m.uid).toSet();
      return [
        for (final uid in mess.rotationOrder)
          if (known.contains(uid)) uid,
        for (final m in members)
          if (!mess.rotationOrder.contains(m.uid)) m.uid,
      ];
    }
    return members.map((m) => m.uid).toList();
  }

  void _scheduleSyncFromRemote(Mess mess, List<Member> members) {
    final remoteKey =
        '${mess.name}|${mess.currency}|${mess.inviteCode}|${mess.rotationCycle}|${mess.rotationOrder.join(',')}';
    if (_remoteSyncKey == remoteKey) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _applyRemote(mess, members, remoteKey));
    });
  }

  void _applyRemote(Mess mess, List<Member> members, String remoteKey) {
    _remoteSyncKey = remoteKey;

    if (!_generalDirty) {
      if (_nameCtrl.text != mess.name) {
        _nameCtrl.text = mess.name;
      }
      final currency = resolveMessCurrency(mess.currency);
      _currency = currency;
    }

    if (!_rotationDirty && !_rotationBusy) {
      _rotationCycle = mess.rotationCycle == 'monthly'
          ? 'monthly'
          : mess.rotationCycle == 'weekly'
              ? 'weekly'
              : 'daily';
      _rotationUids = _rotationFromMess(mess, members);
    }
  }

  Future<void> _saveGeneral() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showSnackError(context, StateError('Mess name cannot be empty.'));
      return;
    }
    setState(() => _generalBusy = true);
    try {
      await widget.repo.updateMessGeneral(
        widget.messId,
        name: name,
        currency: _currency,
      );
      if (mounted) {
        setState(() => _generalDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('General settings saved.')),
        );
      }
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _generalBusy = false);
    }
  }

  Future<void> _refreshInvite(Mess mess) async {
    setState(() => _inviteBusy = true);
    try {
      final code = await widget.repo.refreshInviteCode(
        messId: widget.messId,
        uid: widget.profile.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New invite code: $code')),
        );
      }
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  Future<void> _saveRotation() async {
    setState(() => _rotationBusy = true);
    try {
      await widget.repo.updateRotationOrder(
        widget.messId,
        _rotationUids,
        rotationCycle: 'daily',
      );
      if (mounted) {
        setState(() => _rotationDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rotation order saved.')),
        );
      }
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _rotationBusy = false);
    }
  }

  void _moveRotation(int index, int delta) {
    final next = index + delta;
    if (next < 0 || next >= _rotationUids.length) return;
    setState(() {
      _rotationDirty = true;
      final uid = _rotationUids.removeAt(index);
      _rotationUids.insert(next, uid);
    });
  }

  Widget _buildBody(BuildContext context, {required double bottomInset}) {
    return StreamBuilder<Mess?>(
      stream: widget.repo.messStream(widget.messId),
      builder: (_, messSnap) {
        final mess = messSnap.data;
        if (mess == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<Member>>(
          stream: widget.repo.membersStream(widget.messId),
          builder: (_, membersSnap) {
            final members = membersSnap.data ?? const <Member>[];
            _scheduleSyncFromRemote(mess, members);
            final memberMap = {for (final m in members) m.uid: m};

            return ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
              children: [
                Text(
                  'Admin settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your mess identity, financial settings, and room logistics.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
                  const SizedBox(height: 20),
                  _SettingsCard(
                    icon: Icons.tune_rounded,
                    title: 'General settings',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _currency,
                          decoration: borderedField(
                            label: 'Mess currency',
                            prefix: Icon(Icons.payments_outlined,
                                color: AppColors.onSurfaceVariant),
                          ),
                          items: messCurrencyOrder
                              .map(
                                (code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(messCurrencyMeta[code]!.label),
                                ),
                              )
                              .toList(),
                          onChanged: _generalBusy
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _generalDirty = true;
                                    _currency = v;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameCtrl,
                          enabled: !_generalBusy,
                          onChanged: (_) {
                            if (!_generalDirty) setState(() => _generalDirty = true);
                          },
                          decoration: borderedField(
                            label: 'Mess name',
                            prefix: Icon(Icons.apartment_rounded,
                                color: AppColors.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _generalBusy ? null : _saveGeneral,
                          child: _generalBusy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save changes'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsCard(
                    icon: Icons.meeting_room_outlined,
                    title: 'Room management',
                    trailing: Chip(
                      label: const Text('Active'),
                      avatar: Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.secondary),
                      backgroundColor: AppColors.secondaryContainerTint,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainerTint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.outlineVariant.withValues(alpha: 0.6),
                              width: 1.5,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'JOINING CODE',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      letterSpacing: 0.12,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    mess.inviteCode,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primaryDark,
                                          letterSpacing: 4,
                                        ),
                                  ),
                                  IconButton(
                                    tooltip: 'Copy code',
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: mess.inviteCode),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Invite code copied.')),
                                      );
                                    },
                                    icon: const Icon(Icons.content_copy_rounded),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Share this code with new members so they can join your mess.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _inviteBusy ? null : () => _refreshInvite(mess),
                          icon: _inviteBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: const Text('Revoke & refresh code'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsCard(
                    icon: Icons.autorenew_rounded,
                    title: 'Grocery rotation',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Drag order with ↑↓. First member is on duty today. Duty advances to the next person each day automatically.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),
                        if (_rotationUids.isEmpty)
                          Text(
                            'Add members before configuring rotation.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          )
                        else
                          for (var i = 0; i < _rotationUids.length; i++)
                            _RotationTile(
                              member: memberMap[_rotationUids[i]],
                              index: i,
                              isCurrent: i == 0,
                              onUp: i > 0 ? () => _moveRotation(i, -1) : null,
                              onDown: i < _rotationUids.length - 1
                                  ? () => _moveRotation(i, 1)
                                  : null,
                            ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed:
                              _rotationBusy || _rotationUids.isEmpty ? null : _saveRotation,
                          child: _rotationBusy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save rotation'),
                        ),
                      ],
                    ),
                  ),
                  if (widget.embedded) ...[
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: widget.repo.signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ],
              );
            },
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final navExtra = widget.embedded ? kBottomNavigationBarHeight : 0.0;
    final bottomInset = MediaQuery.paddingOf(context).bottom + navExtra + 24;
    final profile = SessionScope.maybeOf(context)?.profile ?? widget.profile;

    return MessAdminBuilder(
      repo: widget.repo,
      messId: widget.messId,
      profile: profile,
      builder: (context, isAdmin) {
        if (!isAdmin) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Admin access only', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Only mess admins can open these settings. Ask an admin to promote you in Members.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        final body = _buildBody(context, bottomInset: bottomInset);
        if (widget.embedded) return body;

        return Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: const Text('Admin settings'),
          ),
          body: body,
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _RotationTile extends StatelessWidget {
  const _RotationTile({
    required this.member,
    required this.index,
    required this.isCurrent,
    this.onUp,
    this.onDown,
  });

  final Member? member;
  final int index;
  final bool isCurrent;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final name = member?.displayName ?? 'Member';
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final subtitle = isCurrent
        ? 'Current'
        : index == 1
        ? 'Next in line'
        : 'Waiting';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? AppColors.primaryDark : AppColors.outlineVariant.withValues(alpha: 0.5),
          width: isCurrent ? 2 : 1,
        ),
        color: isCurrent ? AppColors.primaryDark.withValues(alpha: 0.06) : Colors.white,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isCurrent ? AppColors.primaryDark : AppColors.secondary,
            child: Text(initial, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onUp, icon: const Icon(Icons.arrow_upward_rounded)),
          IconButton(onPressed: onDown, icon: const Icon(Icons.arrow_downward_rounded)),
        ],
      ),
    );
  }
}
