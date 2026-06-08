import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

/// Enforces required store updates and optional update prompts (Android Play in-app update when available).
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> with WidgetsBindingObserver {
  StoreUpdateCheck? _requiredUpdate;
  StoreUpdateCheck? _optionalUpdate;
  var _checkingOptional = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshUpdates());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshUpdates());
    }
  }

  Future<void> _refreshUpdates() async {
    final result = await AppUpdateService.instance.runUpdateCycle();
    if (!mounted) return;

    if (result.kind == StoreUpdateKind.required) {
      setState(() {
        _requiredUpdate = result;
        _optionalUpdate = null;
      });
      return;
    }

    setState(() => _requiredUpdate = null);

    if (result.kind == StoreUpdateKind.optional) {
      if (!kIsWeb && Platform.isAndroid) {
        final handled = await AppUpdateService.instance.tryAndroidFlexibleUpdate();
        if (handled || !mounted) return;
      }
      setState(() => _optionalUpdate = result);
    } else {
      setState(() => _optionalUpdate = null);
    }
  }

  Future<void> _openStore(StoreUpdateCheck check) async {
    await AppUpdateService.instance.openStoreListing(check.storeUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (_requiredUpdate != null) {
      return _ForceUpdateScreen(
        check: _requiredUpdate!,
        onUpdate: () => _openStore(_requiredUpdate!),
      );
    }

    return Stack(
      children: [
        widget.child,
        if (_optionalUpdate != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                color: AppColors.primaryDark,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _checkingOptional
                      ? null
                      : () async {
                          setState(() => _checkingOptional = true);
                          try {
                            if (!kIsWeb && Platform.isAndroid) {
                              final ok = await AppUpdateService.instance.tryAndroidFlexibleUpdate();
                              if (ok && mounted) {
                                setState(() => _optionalUpdate = null);
                                return;
                              }
                            }
                            await _openStore(_optionalUpdate!);
                          } finally {
                            if (mounted) setState(() => _checkingOptional = false);
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.system_update_alt_rounded, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Update available',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Version ${_optionalUpdate!.targetVersionLabel} is ready',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _optionalUpdate = null),
                          child: const Text('Later', style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({required this.check, required this.onUpdate});

  final StoreUpdateCheck check;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final notes = check.policy.releaseNotes.trim();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upgrade_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Update required',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please install version ${check.targetVersionLabel} from the ${!kIsWeb && Platform.isIOS ? 'App Store' : 'Play Store'} to continue.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(notes, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onUpdate,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Update now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
