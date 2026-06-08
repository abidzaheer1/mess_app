import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SetupMessScreen extends StatefulWidget {
  const SetupMessScreen({
    super.key,
    required this.repo,
    required this.uid,
    required this.displayNameSuggestion,
  });

  final MessRepository repo;
  final String uid;
  final String displayNameSuggestion;

  @override
  State<SetupMessScreen> createState() => _SetupMessScreenState();
}

class _SetupMessScreenState extends State<SetupMessScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _messName = TextEditingController();
  final _inviteCode = TextEditingController();
  late final TextEditingController _createMemberName;
  late final TextEditingController _joinMemberName;
  var _creating = false;
  var _joining = false;

  @override
  void initState() {
    super.initState();
    _createMemberName = TextEditingController(text: widget.displayNameSuggestion);
    _joinMemberName = TextEditingController(text: widget.displayNameSuggestion);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _messName.dispose();
    _inviteCode.dispose();
    _createMemberName.dispose();
    _joinMemberName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final messName = _messName.text.trim();
    final display = _createMemberName.text.trim();
    if (messName.isEmpty) {
      showSnackError(context, StateError('Enter a mess name.'));
      return;
    }
    if (display.isEmpty) {
      showSnackError(context, StateError('Enter how members should see you.'));
      return;
    }

    setState(() => _creating = true);
    try {
      final res = await widget.repo.createMess(
        uid: widget.uid,
        userName: display,
        name: messName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share invite code ${res.inviteCode} with your housemates')),
      );
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _join() async {
    final display = _joinMemberName.text.trim();
    final rawCode = _inviteCode.text.trim();
    final code = parseInviteCodeFromQr(rawCode) ?? rawCode.toUpperCase();
    if (display.isEmpty) {
      showSnackError(context, StateError('Enter your display name.'));
      return;
    }
    if (code.length < 4) {
      showSnackError(context, StateError('Enter the invite code your admin shared.'));
      return;
    }

    setState(() => _joining = true);
    try {
      await widget.repo.requestJoinMess(
        uid: widget.uid,
        userName: display,
        inviteCodeRaw: code,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join request sent. Waiting for admin approval.'),
        ),
      );
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.paddingOf(context).bottom);

    return Scaffold(
      appBar: AppBar(title: const Text('Setup your mess')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Text(
              'Create your communal ledger or paste an invite to join someone else’s mess.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'Create mess'),
              Tab(text: 'Join mess'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ListView(
                  padding: pad,
                  children: [
                    TextField(
                      controller: _messName,
                      textCapitalization: TextCapitalization.words,
                      decoration: borderedField(
                        label: 'Mess name',
                        hint: 'Omega House Collective',
                        prefix: Icon(Icons.home_work_outlined, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _createMemberName,
                      decoration: borderedField(
                        label: 'Your display name',
                        hint: widget.displayNameSuggestion,
                        prefix: Icon(Icons.person_outline_rounded, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _creating ? null : _create,
                      child: _creating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create mess'),
                    ),
                  ],
                ),
                ListView(
                  padding: pad,
                  children: [
                    TextField(
                      controller: _inviteCode,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: borderedField(
                        label: 'Invite code',
                        hint: 'ABCDEF',
                        prefix: Icon(Icons.lock_outline_rounded, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _joinMemberName,
                      decoration: borderedField(
                        label: 'Your display name',
                        hint: widget.displayNameSuggestion,
                        prefix: Icon(Icons.person_outline_rounded, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _joining ? null : _join,
                      child: _joining
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Request to join'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
