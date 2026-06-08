import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';

class MessInviteCard extends StatelessWidget {
  const MessInviteCard({
    super.key,
    required this.inviteCode,
    this.compact = false,
  });

  final String inviteCode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final qrData = messInviteQrPayload(inviteCode);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Invite to join',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Share the code or QR so new members can request to join.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainerTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.6),
                  width: 1.5,
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
                      Flexible(
                        child: Text(
                          inviteCode,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryDark,
                                letterSpacing: 3,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy code',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: inviteCode));
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
            if (!compact) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Scan to join',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
