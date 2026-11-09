import 'package:flutter/material.dart';
import '../models/clinical_notification.dart';
import '../services/workspace_store.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_pill.dart';

class NotificationCenterView extends StatefulWidget {
  const NotificationCenterView({super.key});

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Opening the notification center counts as reading everything in it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ClinicalNotificationRepository().markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ClinicalNotificationRepository(), WorkspaceStore.instance]),
      builder: (context, child) {
        final repo = ClinicalNotificationRepository();
        final allNotifications = repo.notifications;

        // Deduplicate and filter out any invalid/placeholder mock entries
        final seenIds = <String>{};
        final seenSignatures = <String>{};
        final cleanedNotifications = <ClinicalNotification>[];

        for (final n in allNotifications) {
          if (n.isPlaceholderOrEmpty) continue;
          if (n.id.isNotEmpty && !seenIds.add(n.id)) continue;
          final sig = '${n.title.trim().toLowerCase()}|${n.message.trim().toLowerCase()}|${(n.patientId ?? '').trim().toLowerCase()}|${n.category.toLowerCase()}';
          if (!seenSignatures.add(sig)) continue;
          cleanedNotifications.add(n);
        }

        final filteredNotifications = cleanedNotifications.where((n) {
          final catLower = n.category.toLowerCase();
          if (_selectedFilter == 'Urgent') {
            return n.severity == NotificationSeverity.urgent || catLower.contains('urgent');
          }
          if (_selectedFilter == 'Reminders') {
            return catLower.contains('reminder');
          }
          if (_selectedFilter == 'Refills') {
            return catLower.contains('refill');
          }
          return true;
        }).toList();

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.notifications_active_rounded, color: AppTheme.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clinical Alerts & Notifications',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cleanedNotifications.length} alert${cleanedNotifications.length == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final filter in ['All', 'Urgent', 'Reminders', 'Refills'])
                          FilterPill(
                            label: filter,
                            selected: _selectedFilter == filter,
                            onSelected: () => setState(() => _selectedFilter = filter),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notification List / Empty State
                  if (filteredNotifications.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredNotifications.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final n = filteredNotifications[idx];
                        return _buildNotificationCard(n);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _selectedFilter != 'All';
    return Container(
      key: const Key('notifications_empty_state'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, size: 40, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No Matching Alerts' : 'All Caught Up!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'There are no clinical alerts matching the "$_selectedFilter" filter.'
                : 'No new alerts or pending reminders at this time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(ClinicalNotification n) {
    final isUrgent = n.severity == NotificationSeverity.urgent;
    final tagBg = isUrgent
        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
        : AppTheme.primaryBlue.withValues(alpha: 0.1);
    final tagColor = isUrgent ? const Color(0xFFEF4444) : AppTheme.primaryBlue;

    return Container(
      key: Key('notification_card_${n.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  n.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tagColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTimeAgo(n.timestamp),
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          if (n.title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              n.title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
            ),
          ],
          if (n.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              n.message,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
          if (n.patientName != null && n.patientName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${n.patientName}${n.patientId != null && n.patientId!.isNotEmpty ? " (${n.patientId})" : ""}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
