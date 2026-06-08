import 'package:flutter/material.dart';

import '../../repositories/mess_repository.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.repo, this.initialEmail = ''});

  final MessRepository repo;
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  var _busy = false;
  var _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.repo.sendPasswordResetEmail(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      title: 'Reset password',
      subtitle: _sent
          ? 'Check your inbox for a reset link.'
          : 'Enter your email and we\'ll send you a link to reset your password.',
      child: _sent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.mark_email_read_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'If an account exists for ${_email.text.trim()}, you\'ll receive an email shortly.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to login'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: borderedField(
                      label: 'Email address',
                      hint: 'you@email.com',
                      prefix: Icon(Icons.mail_outline_rounded, color: Theme.of(context).colorScheme.primary),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send reset link'),
                  ),
                ],
              ),
            ),
    );
  }
}
