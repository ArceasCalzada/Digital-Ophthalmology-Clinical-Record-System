import 'package:flutter/material.dart';

import '../services/offline_sync_service.dart';
import '../theme/app_theme.dart';

class SyncStatusIndicator extends StatelessWidget {
  final bool compact;

  /// Show only the status icon (the wording stays in the tooltip). Used in the
  /// collapsed sidebar, which is too narrow for the label.
  final bool iconOnly;

  const SyncStatusIndicator({super.key, this.compact = false, this.iconOnly = false});

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
            final isDark = Theme.of(context).brightness == Brightness.dark || ThemeController.instance.isDarkMode;
            final isOffline = syncService.isOffline;
            final isSyncing = syncService.syncState == SyncStatusState.syncing;
            final pendingCount = syncService.pendingCount;
            final lastSyncedText = _formatTimestamp(syncService.lastSyncedAt);

            final stateColor = isOffline
                ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                : (isSyncing
                    ? (isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue)
                    : (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981)));

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isOffline
                          ? Icons.wifi_off_rounded
                          : (isSyncing ? Icons.sync_rounded : Icons.cloud_done_rounded),
                      color: stateColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Offline-First & Cloud Sync',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Summary Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : AppTheme.borderColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Connectivity State:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isOffline
                                      ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7))
                                      : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFD1FAE5)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isOffline ? 'OFFLINE' : 'ONLINE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOffline
                                        ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                                        : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sync Status:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                isSyncing
                                    ? 'Syncing...'
                                    : (isOffline
                                        ? 'Offline - Changes saved locally'
                                        : 'Synced with Firebase'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: stateColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pending Queue:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '$pendingCount mutations',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Last Synced:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                lastSyncedText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
                                ),
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
                          color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.5) : const Color(0xFFFCA5A5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  syncService.hasPermissionError ? Icons.lock_person_outlined : Icons.error_outline_rounded,
                                  size: 16,
                                  color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${syncService.failedMutations.length} change(s) were NOT saved to the cloud',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (syncService.hasPermissionError) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Permission Denied: Your account does not have write access to this workspace. Please contact your clinic administrator to ensure your role is Editor, Physician, or Owner.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
                                        height: 1.3,
                                      ),
                                    ),
                                    if (syncService.lastError != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        syncService.lastError!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D),
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ] else ...[
                              Text(
                                syncService.lastError ?? 'The server rejected the change.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
                                ),
                              ),
                            ],
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
                    const SizedBox(height: 14),

                    // Data Integrity Reassurance Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF059669).withValues(alpha: 0.5)
                              : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Local-First Guarantee',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Data Integrity Protected: All patient records, examination logs, drawing strokes, and prescriptions are immediately written to local offline persistence storage first and queued safely. Nothing is lost if the clinic loses internet.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF166534),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Toggle Network Connection Switch (for offline testing)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Simulate Network Connection',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        isOffline
                            ? 'Currently Offline (Operating offline, changes cached locally)'
                            : 'Currently Online (Automatic cloud synchronization active)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
                        ),
                      ),
                      value: !isOffline,
                      activeTrackColor: AppTheme.primaryBlue,
                      onChanged: (val) {
                        syncService.setNetworkState(
                          val ? NetworkConnectivityState.online : NetworkConnectivityState.offline,
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isSyncing
                      ? null
                      : () async {
                          if (syncService.failedMutations.isNotEmpty) {
                            await syncService.retryFailed();
                          } else {
                            await syncService.syncNow(force: true);
                          }
                        },
                  icon: isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(
                    isSyncing ? 'Syncing...' : 'Sync Now',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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

  Widget _buildRetryButton(BuildContext context, OfflineSyncService syncService, Color color) {
    return Tooltip(
      message: 'Force retry pending writes now',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('sync-indicator-retry-button'),
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            if (syncService.failedMutations.isNotEmpty) {
              await syncService.retryFailed();
            } else {
              await syncService.syncNow(force: true);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 12, color: color),
                const SizedBox(width: 3),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncService = OfflineSyncService();

    return ListenableBuilder(
      listenable: syncService,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark || ThemeController.instance.isDarkMode;
        final isOffline = syncService.isOffline;
        final isSyncing = syncService.syncState == SyncStatusState.syncing;
        final pendingCount = syncService.pendingCount;
        final failedCount = syncService.failedMutations.length;
        final hasFailed = failedCount > 0;
        final hasPending = pendingCount > 0;
        final lastSyncedText = _formatTimestamp(syncService.lastSyncedAt);

        Color badgeColor;
        IconData badgeIcon;
        String statusLabel;
        String tooltipText;

        if (isSyncing) {
          badgeColor = isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue;
          badgeIcon = Icons.sync_rounded;
          statusLabel = 'Syncing...';
          tooltipText = 'Syncing... Actively uploading queued writes to Firebase database.';
        } else if (hasFailed) {
          badgeColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
          badgeIcon = Icons.error_outline_rounded;
          statusLabel = 'Not saved ($failedCount)';
          tooltipText = 'Some changes were rejected by the server and are not saved. Tap for details.';
        } else if (isOffline) {
          badgeColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
          badgeIcon = Icons.wifi_off_rounded;
          statusLabel = 'Offline - Changes saved locally';
          tooltipText = hasPending
              ? 'Offline - Changes saved locally. $pendingCount writes queued safely on device; will sync automatically upon reconnection.'
              : 'Offline - Changes saved locally. Operating offline; data is cached locally and will sync upon reconnection.';
        } else if (hasPending) {
          badgeColor = isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue;
          badgeIcon = Icons.cloud_upload_outlined;
          statusLabel = 'Syncing...';
          tooltipText = 'Pending cloud synchronization: $pendingCount local writes uploading to Firebase.';
        } else {
          badgeColor = isDark ? const Color(0xFF34D399) : const Color(0xFF10B981);
          badgeIcon = Icons.cloud_done_rounded;
          statusLabel = 'Synced with Firebase';
          tooltipText = 'Synced with Firebase. All local patient records, exam logs, and prescriptions are synchronized. Last synced: $lastSyncedText';
        }

        final badgeWidget = Tooltip(
          message: tooltipText,
          child: InkWell(
            key: const ValueKey('sync-status-indicator-badge'),
            onTap: () => _showSyncDetailsModal(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: badgeColor.withValues(alpha: isDark ? 0.45 : 0.3),
                ),
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
                  if (!iconOnly) ...[
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        statusLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 10 : 11,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        return Row(
          key: const ValueKey('sync-status-indicator-root'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: badgeWidget),
            if (!iconOnly && (hasFailed || (isOffline && hasPending)) && !isSyncing)
              _buildRetryButton(context, syncService, badgeColor),
          ],
        );
      },
    );
  }
}
