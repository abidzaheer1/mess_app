import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';

import 'models/app_models.dart';
import 'repositories/mess_repository.dart';
import 'services/mess_notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/complete_profile_screen.dart';
import 'screens/onboarding/pending_join_screen.dart';
import 'screens/onboarding/setup_mess_screen.dart';
import 'screens/shell/main_shell.dart';
import 'session/session_scope.dart';
import 'widgets/common.dart';
import 'widgets/live_notification_scope.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.repo});

  final MessRepository repo;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  auth.User? _boundUser;
  var _basicsReady = false;
  var _hydratingRole = false;
  String? _hydratedForUid;

  Future<void> _ensureBasics(auth.User user) async {
    if (_boundUser?.uid == user.uid && _basicsReady) return;
    _boundUser = user;
    _basicsReady = false;
    _hydratedForUid = null;
    await widget.repo.ensureUserBasics(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
    if (mounted) setState(() => _basicsReady = true);
  }

  Future<void> _maybeHydrateRole(UserProfile profile) async {
    if (profile.messId == null || profile.role != null) return;
    if (_hydratingRole || _hydratedForUid == profile.uid) return;
    _hydratingRole = true;
    _hydratedForUid = profile.uid;
    try {
      await widget.repo.hydrateProfileRole(profile);
    } finally {
      _hydratingRole = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<auth.User?>(
      stream: widget.repo.authChanges,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting &&
            !authSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnap.data;
        if (user == null) {
          _boundUser = null;
          _basicsReady = false;
          _hydratedForUid = null;
          MessNotificationService.instance.stop();
          return LoginScreen(repo: widget.repo);
        }

        if (_boundUser?.uid != user.uid || !_basicsReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (_boundUser?.uid != user.uid || !_basicsReady)) {
              _ensureBasics(user);
            }
          });
        }

        if (!_basicsReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<UserProfile?>(
          stream: widget.repo.profileStream(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.hasError) {
              return _SessionErrorView(
                message: authErrorMessage(profileSnap.error!),
                onRetry: () => setState(() => _basicsReady = false),
                onSignOut: widget.repo.signOut,
              );
            }

            if (profileSnap.connectionState == ConnectionState.waiting &&
                !profileSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnap.data;
            if (profile == null) {
              return _SessionErrorView(
                message:
                    'Your profile could not be loaded. '
                    'Check your connection and try again.',
                onRetry: () => setState(() => _basicsReady = false),
                onSignOut: widget.repo.signOut,
              );
            }

            _maybeHydrateRole(profile);

            if (profile.messId == null) {
              final pending = profile.pendingJoin;
              if (pending != null &&
                  pending.messId.isNotEmpty &&
                  pending.requestId.isNotEmpty) {
                return PendingJoinScreen(
                  repo: widget.repo,
                  profile: profile,
                  pending: pending,
                );
              }
              return SetupMessScreen(
                repo: widget.repo,
                uid: profile.uid,
                displayNameSuggestion: profile.displayName,
              );
            }

            if (!profile.profileComplete) {
              return SessionScope(
                profile: profile,
                child: CompleteProfileScreen(repo: widget.repo, profile: profile),
              );
            }

            return SessionScope(
              profile: profile,
              child: LiveNotificationScope(
                repo: widget.repo,
                messId: profile.messId!,
                uid: profile.uid,
                child: MainShell(repo: widget.repo),
              ),
            );
          },
        );
      },
    );
  }
}

class _SessionErrorView extends StatelessWidget {
  const _SessionErrorView({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not sign you in',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              TextButton(
                onPressed: onSignOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
