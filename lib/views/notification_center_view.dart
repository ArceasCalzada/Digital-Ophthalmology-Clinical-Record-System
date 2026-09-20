import 'package:flutter/material.dart';
import '../models/clinical_notification.dart';
import '../theme/app_theme.dart';

class NotificationCenterView extends StatefulWidget {
  const NotificationCenterView({super.key});

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView> {
  String _selectedFilter = 'All';

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Clinical Alerts & Notifications',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            Text(
                              '${repo.unreadCount} unread alert${repo.unreadCount == 1 ? '' : 's'}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (repo.unreadCount > 0)
                      TextButton.icon(
                        onPressed: () => repo.markAllAsRead(),
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Mark all read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Urgent', 'Reminders', 'Refills'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedFilter = filter);
                          },
                          selectedColor: AppTheme.primaryBlue,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryBlue : AppTheme.borderColor,
                          ),
                        ),
                      );
                    }).toList(),
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
                          'There are no unread clinical alerts matching this filter.',
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
                      return _buildNotificationCard(n, repo);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(ClinicalNotification n, ClinicalNotificationRepository repo) {
    Color badgeColor;
    IconData badgeIcon;

    switch (n.severity) {
      case NotificationSeverity.urgent:
        badgeColor = const Color(0xFFEF4444);
        badgeIcon = Icons.warning_amber_rounded;
        break;
      case NotificationSeverity.warning:
        badgeColor = const Color(0xFFF59E0B);
        badgeIcon = Icons.error_outline_rounded;
        break;
      case NotificationSeverity.info:
        badgeColor = AppTheme.primaryBlue;
        badgeIcon = Icons.info_outline_rounded;
        break;
    }

    final formattedTime = _formatTimeAgo(n.timestamp);

    return Container(
      decoration: BoxDecoration(
        color: n.isRead ? Colors.white : badgeColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: n.isRead ? AppTheme.borderColor : badgeColor.withValues(alpha: 0.3),
          width: n.isRead ? 1 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => repo.markAsRead(n.id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(badgeIcon, color: badgeColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  n.category.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formattedTime,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                              if (!n.isRead) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  n.message,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                if (n.patientName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.account_circle_outlined, size: 14, color: AppTheme.primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        '${n.patientName} (${n.patientId ?? ''})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!n.isRead)
                      TextButton.icon(
                        onPressed: () => repo.markAsRead(n.id),
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Mark Read', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => repo.dismissNotification(n.id),
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Dismiss', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
