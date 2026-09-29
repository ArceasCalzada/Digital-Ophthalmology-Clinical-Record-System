import 'package:flutter/material.dart';

import '../services/offline_sync_service.dart';
import '../theme/app_theme.dart';

class SyncStatusIndicator extends StatelessWidget {
  final bool compact;

  const SyncStatusIndicator({super.key, this.compact = false});

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return 'Never synced';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  void _showSyncDetailsModal(BuildContext context) {
    final syncService = OfflineSyncService();

    showDialog(
      context: context,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: syncService,
          builder: (context, _) {
            final isOffline = syncService.isOffline;
            final isSyncing = syncService.syncState == SyncStatusState.syncing;
            final pendingCount = syncService.pendingCount;
            final lastSyncedText = _formatTimestamp(syncService.lastSyncedAt);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOffline
                          ? const Color(0xFFD97706).withValues(alpha: 0.1)
                          : (isSyncing
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : const Color(0xFF10B981).withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isOffline
                          ? Icons.wifi_off_rounded
                          : (isSyncing ? Icons.sync_rounded : Icons.cloud_done_rounded),
                      color: isOffline
                          ? const Color(0xFFD97706)
                          : (isSyncing ? AppTheme.primaryBlue : const Color(0xFF10B981)),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Offline-First & Cloud Sync',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Summary Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Connectivity State:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOffline ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isOffline ? 'OFFLINE' : 'ONLINE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isOffline ? const Color(0xFFB45309) : const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pending Queue:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                            ),
                            Text(
                              '$pendingCount mutations',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Last Synced:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                            ),
                            Text(
                              lastSyncedText,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (syncService.failedMutations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${syncService.failedMutations.length} change(s) were NOT saved to the cloud',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            syncService.lastError ?? 'The server rejected the change.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: syncService.retryFailed,
                                child: const Text('Retry'),
                              ),
                              TextButton(
                                onPressed: syncService.discardFailed,
                                child: const Text('Discard'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  const Text(
                    'Local-First Guarantee',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'All reads and writes execute locally first without blocking on network requests. Changes saved offline are queued and auto-synced when online.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 16),

                  // Toggle Network Connection Switch (for offline testing)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Simulate Network Connection', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isOffline ? 'Currently Offline (Saving locally)' : 'Currently Online (Background sync active)',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    value: !isOffline,
                    activeTrackColor: AppTheme.primaryBlue,
                    onChanged: (val) {
                      syncService.setNetworkState(val ? NetworkConnectivityState.online : NetworkConnectivityState.offline);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: isSyncing
                      ? null
                      : () async {
                          await syncService.syncNow();
                        },
                  icon: isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(isSyncing ? 'Syncing...' : 'Sync Now', style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncService = OfflineSyncService();

    return ListenableBuilder(
      listenable: syncService,
      builder: (context, _) {
        final isOffline = syncService.isOffline;
        final isSyncing = syncService.syncState == SyncStatusState.syncing;
        final pendingCount = syncService.pendingCount;
        final lastSyncedText = _formatTimestamp(syncService.lastSyncedAt);

        Color badgeColor;
        IconData badgeIcon;
        String statusLabel;

        if (isSyncing) {
          badgeColor = AppTheme.primaryBlue;
          badgeIcon = Icons.sync_rounded;
          statusLabel = 'Syncing...';
        } else if (syncService.failedMutations.isNotEmpty) {
          badgeColor = const Color(0xFFDC2626);
          badgeIcon = Icons.error_outline_rounded;
          statusLabel = 'Not saved (${syncService.failedMutations.length})';
        } else if (isOffline) {
          badgeColor = const Color(0xFFD97706);
          badgeIcon = Icons.wifi_off_rounded;
          statusLabel = pendingCount > 0 ? 'Offline ($pendingCount saved)' : 'Offline (Saved locally)';
        } else {
          badgeColor = const Color(0xFF10B981);
          badgeIcon = Icons.cloud_done_rounded;
          statusLabel = 'Up to date';
        }

        final tooltipText = syncService.failedMutations.isNotEmpty
            ? 'Some changes were rejected by the server and are not saved. Tap for details.'
            : isOffline
            ? 'Offline mode: Changes saved locally. Pending: $pendingCount'
            : (isSyncing ? 'Synchronizing payload with cloud...' : 'Up to date. Last synced: $lastSyncedText');

        return Tooltip(
          message: tooltipText,
          child: InkWell(
            onTap: () => _showSyncDetailsModal(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSyncing)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: badgeColor),
                    )
                  else
                    Icon(badgeIcon, size: 14, color: badgeColor),
                  const SizedBox(width: 5),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
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
