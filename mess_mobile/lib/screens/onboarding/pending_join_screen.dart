import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PendingJoinScreen extends StatefulWidget {
  const PendingJoinScreen({
    super.key,
    required this.repo,
    required this.profile,
    required this.pending,
  });

  final MessRepository repo;
  final UserProfile profile;
  final PendingJoin pending;

  @override
  State<PendingJoinScreen> createState() => _PendingJoinScreenState();
}

class _PendingJoinScreenState extends State<PendingJoinScreen> {
  var _finalizing = false;

  Future<void> _tryFinalize(JoinRequest request) async {
    if (request.status != JoinRequestStatuses.approved) return;
    setState(() => _finalizing = true);
    try {
      await widget.repo.finalizeJoinAfterApproval(
        uid: widget.profile.uid,
        messId: widget.pending.messId,
        requestId: widget.pending.requestId,
      );
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  Future<void> _cancelAndRetry() async {
    await widget.repo.cancelJoinRequest(
      messId: widget.pending.messId,
      requestId: widget.pending.requestId,
      uid: widget.profile.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pending.isRejected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Join request')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel_outlined, size: 56, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Request declined',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The mess admin did not approve your join request. You can try another invite code.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  await _cancelAndRetry();
                },
                child: const Text('Try another code'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<JoinRequest?>(
      stream: widget.repo.joinRequestStream(
        widget.pending.messId,
        widget.pending.requestId,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Join request')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    authErrorMessage(snap.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      await widget.repo.clearPendingJoin(widget.profile.uid);
                    },
                    child: const Text('Clear and try again'),
                  ),
                ],
              ),
            ),
          );
        }

        final request = snap.data;
        if (snap.connectionState == ConnectionState.active && request == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Join request')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'This join request is no longer available. Enter a new invite code.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      await widget.repo.clearPendingJoin(widget.profile.uid);
                    },
                    child: const Text('Try another code'),
                  ),
                ],
              ),
            ),
          );
        }
        if (request?.status == JoinRequestStatuses.approved) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryFinalize(request!));
        }
        if (request?.status == JoinRequestStatuses.rejected) {
          return Scaffold(
            appBar: AppBar(title: const Text('Join request')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, size: 56, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Request declined',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The mess admin did not approve your join request. You can try another invite code.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      await _cancelAndRetry();
                    },
                    child: const Text('Try another code'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Join request')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_finalizing)
                    const CircularProgressIndicator()
                  else
                    Icon(Icons.hourglass_top_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  Text(
                    _finalizing ? 'Joining mess…' : 'Waiting for admin approval',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    request == null
                        ? 'Loading your request…'
                        : 'Your request to join was sent. An admin will approve or decline it. '
                            'Expenses before you join will not include you in the split.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: _finalizing ? null : _cancelAndRetry,
                    child: const Text('Cancel request'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
