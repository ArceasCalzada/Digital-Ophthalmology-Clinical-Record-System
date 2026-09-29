import 'package:flutter/material.dart';
import '../models/clinical_notification.dart';
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
    // Deferred so listeners (the unread badges) aren't notified during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ClinicalNotificationRepository().markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ClinicalNotificationRepository(),
      builder: (context, child) {
        final repo = ClinicalNotificationRepository();
        final allNotifications = repo.notifications;

        final filteredNotifications = allNotifications.where((n) {
          if (_selectedFilter == 'Urgent') return n.severity == NotificationSeverity.urgent;
          if (_selectedFilter == 'Reminders') return n.category == 'Reminder';
          if (_selectedFilter == 'Refills') return n.category == 'Refill';
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: AppTheme.lightBg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Row(
                  children: [
                    Expanded(
                      child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryBlue, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Clinical Alerts & Notifications',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              Text(
                                '${allNotifications.length} alert${allNotifications.length == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_none_rounded, size: 36, color: AppTheme.primaryBlue),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'All Alerts Clear!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'There are no clinical alerts matching this filter.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredNotifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final n = filteredNotifications[idx];
                      return _buildNotificationCard(n);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Every notification looks the same: category and urgency are told apart by the
  // label and the filter pills, not by colour or icons.
  Widget _buildNotificationCard(ClinicalNotification n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  n.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTimeAgo(n.timestamp),
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            n.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            n.message,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
          if (n.patientName != null) ...[
            const SizedBox(height: 8),
            Text(
              '${n.patientName} (${n.patientId ?? ''})',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
            ),
          ],
        ],
      ),
    );
  }
  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
