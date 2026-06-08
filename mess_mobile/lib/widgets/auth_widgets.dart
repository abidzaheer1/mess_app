import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/password_validation.dart';
import 'common.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leading != null) Align(alignment: Alignment.centerLeft, child: leading!),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apartment_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Alpha Mess',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(padding: const EdgeInsets.all(24), child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed, this.busy = false, this.label = 'Continue with Google'});

  final VoidCallback? onPressed;
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.8)),
      ),
      icon: busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.g_mobiledata_rounded, size: 26),
      label: Text(label),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'or'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint = 'Enter password',
    this.showStrength = false,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool showStrength;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          decoration: borderedField(
            label: widget.label,
            hint: widget.hint,
            prefix: Icon(Icons.lock_outline_rounded, color: AppColors.onSurfaceVariant),
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: widget.validator,
          onChanged: widget.showStrength ? (_) => setState(() {}) : null,
        ),
        if (widget.showStrength && widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _PasswordStrengthBar(password: widget.controller.text),
        ],
      ],
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final result = validatePassword(password);
    final color = result.isValid
        ? AppColors.secondary
        : result.score >= 2
            ? Colors.orange
            : Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (result.score.clamp(0, 5)) / 5,
            minHeight: 6,
            backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.4),
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          result.message,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
