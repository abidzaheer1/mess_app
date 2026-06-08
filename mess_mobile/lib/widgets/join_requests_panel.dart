import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../repositories/mess_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class JoinRequestsPanel extends StatefulWidget {
  const JoinRequestsPanel({
    super.key,
    required this.repo,
    required this.messId,
    required this.adminUid,
  });

  final MessRepository repo;
  final String messId;
  final String adminUid;

  @override
  State<JoinRequestsPanel> createState() => _JoinRequestsPanelState();
}

class _JoinRequestsPanelState extends State<JoinRequestsPanel> {
  @override
  void initState() {
    super.initState();
    widget.repo.syncJoinAlertsFromRequests(widget.messId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JoinRequest>>(
      stream: widget.repo.pendingJoinRequestsStream(widget.messId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: AppColors.warningSurface,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Could not load join requests',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    authErrorMessage(snap.error!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          );
        }

        final requests = snap.data ?? const <JoinRequest>[];
        if (requests.isEmpty) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No pending join requests',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final dateFmt = DateFormat.MMMd().add_jm();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: AppColors.warningSurface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Join requests (${requests.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final req in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            req.displayName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            'Requested ${dateFmt.format(DateTime.fromMillisecondsSinceEpoch(req.requestedAt))}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await widget.repo.rejectJoinRequest(
                                        messId: widget.messId,
                                        requestId: req.id,
                                        adminUid: widget.adminUid,
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Declined ${req.displayName}')),
                                      );
                                    } catch (e) {
                                      if (context.mounted) showSnackError(context, e);
                                    }
                                  },
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () async {
                                    try {
                                      await widget.repo.approveJoinRequest(
                                        messId: widget.messId,
                                        requestId: req.id,
                                        adminUid: widget.adminUid,
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${req.displayName} approved — split starts from now',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (context.mounted) showSnackError(context, e);
                                    }
                                  },
                                  child: const Text('Approve'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
