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
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Bar
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.notifications_active_rounded, color: AppTheme.primaryBlue, size: 22),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Clinical Alerts & Notifications',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${allNotifications.length} alert${allNotifications.length == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

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
                  SizedBox(height: 16),

                  // Notification List / Empty State
                  if (filteredNotifications.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: filteredNotifications.length,
                      separatorBuilder: (context, index) => SizedBox(height: 12),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, size: 40, color: AppTheme.primaryBlue),
          ),
          SizedBox(height: 16),
          Text(
            'All Alerts Clear!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textPrimary),
          ),
          SizedBox(height: 6),
          Text(
            _selectedFilter == 'All'
                ? 'There are no clinical alerts or notifications at this time.'
                : 'There are no clinical alerts matching this filter.',
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
        ? Color(0xFFEF4444).withValues(alpha: 0.12)
        : AppTheme.primaryBlue.withValues(alpha: 0.1);
    final tagColor = isUrgent ? Color(0xFFEF4444) : AppTheme.primaryBlue;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              Spacer(),
              Text(
                _formatTimeAgo(n.timestamp),
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          if (n.title.isNotEmpty) ...[
            SizedBox(height: 10),
            Text(
              n.title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
            ),
          ],
          if (n.message.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(
              n.message,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
          if (n.patientName != null && n.patientName!.isNotEmpty) ...[
            SizedBox(height: 10),
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
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
