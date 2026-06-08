import 'package:flutter/material.dart';

import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/password_validation.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.repo});

  final MessRepository repo;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  var _googleBusy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.register(_email.text, _password.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignUp() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      final ok = await widget.repo.signInWithGoogle();
      if (!ok && mounted) {
        setState(() => _error = 'Google sign-up was cancelled.');
      } else if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      title: 'Create account',
      subtitle: 'Join your mess group — track expenses, duties, and stay connected.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GoogleSignInButton(
              busy: _googleBusy,
              label: 'Sign up with Google',
              onPressed: _googleSignUp,
            ),
            const SizedBox(height: 16),
            const AuthDivider(label: 'or sign up with email'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: borderedField(
                label: 'Email',
                hint: 'you@email.com',
                prefix: Icon(Icons.mail_outline_rounded, color: AppColors.onSurfaceVariant),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _password,
              label: 'Password',
              hint: 'Strong password',
              showStrength: true,
              validator: passwordFieldValidator,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirm,
              label: 'Confirm password',
              hint: 'Re-enter password',
              validator: (v) {
                if (v != _password.text) return 'Passwords do not match';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _googleBusy ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
