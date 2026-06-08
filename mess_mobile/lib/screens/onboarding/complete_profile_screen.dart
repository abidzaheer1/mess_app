import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, required this.repo, required this.profile});

  final MessRepository repo;
  final UserProfile profile;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile.displayName);
  late final TextEditingController _phone =
      TextEditingController(text: widget.profile.phone ?? '');
  late final TextEditingController _dob =
      TextEditingController(text: widget.profile.dateOfBirth ?? '');
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _dob.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.repo.saveProfile(
        uid: widget.profile.uid,
        displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        dateOfBirth: _dob.text.trim().isEmpty ? null : _dob.text.trim(),
        profileComplete: true,
      );
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete profile')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'Add a friendly name plus optional contacts so admins can recognise you offline.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: borderedField(
              label: 'Display name',
              hint: 'Jordan Lee',
              prefix: Icon(Icons.badge_outlined, color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: borderedField(
              label: 'Phone (optional)',
              hint: '+1 415 555 0100',
              prefix: Icon(Icons.phone_outlined, color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dob,
            decoration: borderedField(
              label: 'Date of birth (optional)',
              hint: 'yyyy-mm-dd',
              prefix: Icon(Icons.cake_outlined, color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save & continue'),
          ),
        ],
      ),
    );
  }
}
