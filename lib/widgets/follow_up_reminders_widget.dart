import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/follow_up_reminder.dart';
import '../models/patient.dart';
import '../services/clinical_reminder_service.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import 'add_event_modal.dart';
import 'filter_pill.dart';

class FollowUpRemindersWidget extends StatefulWidget {
  final Function(Patient)? onSelectPatient;
  final ValueChanged<DateTime?>? onOpenCalendar;
  final String? initialFilter;
  final VoidCallback? onClose;
  final bool showCloseButton;
  final bool isModal;

  const FollowUpRemindersWidget({
    super.key,
    this.onSelectPatient,
    this.onOpenCalendar,
    this.initialFilter,
    this.onClose,
    this.showCloseButton = false,
    this.isModal = false,
  });

  /// Opens the Patient Follow-Up & Return Queue in a modal dialog or bottom sheet
  static Future<void> showModal(
    BuildContext context, {
    Function(Patient)? onSelectPatient,
    ValueChanged<DateTime?>? onOpenCalendar,
    String? initialFilter,
  }) async {
    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: FollowUpRemindersWidget(
                initialFilter: initialFilter,
                showCloseButton: true,
                isModal: true,
                onClose: () => Navigator.of(ctx).pop(),
                onSelectPatient: (patient) {
                  Navigator.of(ctx).pop();
                  onSelectPatient?.call(patient);
                },
                onOpenCalendar: (date) {
                  Navigator.of(ctx).pop();
                  onOpenCalendar?.call(date);
                },
              ),
            ),
          ),
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.cardBg,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840, maxHeight: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: FollowUpRemindersWidget(
                initialFilter: initialFilter,
                showCloseButton: true,
                isModal: true,
                onClose: () => Navigator.of(ctx).pop(),
                onSelectPatient: (patient) {
                  Navigator.of(ctx).pop();
                  onSelectPatient?.call(patient);
                },
                onOpenCalendar: (date) {
                  Navigator.of(ctx).pop();
                  onOpenCalendar?.call(date);
                },
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  State<FollowUpRemindersWidget> createState() => _FollowUpRemindersWidgetState();
}

class _FollowUpRemindersWidgetState extends State<FollowUpRemindersWidget> {
  late String _selectedFilter;

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'All';
  }

  @override
  void didUpdateWidget(covariant FollowUpRemindersWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != null && widget.initialFilter != oldWidget.initialFilter) {
      setState(() {
        _selectedFilter = widget.initialFilter!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ClinicalReminderService.instance,
      builder: (context, _) {
        final service = ClinicalReminderService.instance;
        final allReminders = service.reminders;

        final filtered = allReminders.where((r) {
          final status = r.getStatus();
          if (_selectedFilter == 'Overdue') {
            return status == FollowUpStatus.overdue;
          }
          if (_selectedFilter == 'Due Today') {
            return status == FollowUpStatus.dueToday;
          }
          if (_selectedFilter == 'Due in 3 Days') {
            return status == FollowUpStatus.dueSoon;
          }
          if (_selectedFilter == 'Needs Scheduling') {
            return !r.isScheduled;
          }
          return true;
        }).toList();

        final overdueCount = service.overdueCount;
        final dueTodayCount = service.dueTodayCount;
        final dueSoonCount = service.dueSoonCount;
        final unscheduledCount = service.unscheduledReminders.length;

        final closeButton = widget.showCloseButton
            ? IconButton(
                key: const Key('follow_up_queue_close_button'),
                icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 22),
                tooltip: 'Close',
                splashRadius: 20,
                onPressed: _handleClose,
              )
            : null;

        Widget content = Container(
          key: const Key('follow_up_reminders_widget'),
          decoration: widget.isModal
              ? BoxDecoration(
                  color: AppTheme.cardBg,
                )
              : BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Bar with Clinical Badges
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isCompact = headerConstraints.maxWidth < 700;
                  final badges = Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (overdueCount > 0)
                        _buildSummaryBadge(
                          count: overdueCount,
                          label: 'Overdue',
                          color: const Color(0xFFDC2626),
                          bgColor: const Color(0xFFFEE2E2),
                          onTap: () => setState(() => _selectedFilter = 'Overdue'),
                        ),
                      if (dueTodayCount > 0)
                        _buildSummaryBadge(
                          count: dueTodayCount,
                          label: 'Due Today',
                          color: const Color(0xFFD97706),
                          bgColor: const Color(0xFFFEF3C7),
                          onTap: () => setState(() => _selectedFilter = 'Due Today'),
                        ),
                      if (dueSoonCount > 0)
                        _buildSummaryBadge(
                          count: dueSoonCount,
                          label: 'In 3 Days',
                          color: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFDBEAFE),
                          onTap: () => setState(() => _selectedFilter = 'Due in 3 Days'),
                        ),
                    ],
                  );

                  final titleSection = Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: overdueCount > 0
                              ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                              : AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          overdueCount > 0
                              ? Icons.notification_important_rounded
                              : Icons.access_alarms_rounded,
                          color: overdueCount > 0 ? const Color(0xFFDC2626) : AppTheme.primaryBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Patient Follow-Up & Return Queue',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${allReminders.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Automated scan linking prescriptions & calendar appointments for timely patient returns',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: titleSection),
                            ?closeButton,
                          ],
                        ),
                        if (overdueCount > 0 || dueTodayCount > 0 || dueSoonCount > 0) ...[
                          const SizedBox(height: 10),
                          badges,
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 12),
                      badges,
                      if (closeButton != null) ...[
                        const SizedBox(width: 8),
                        closeButton,
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // 2. Filter Pills Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterPill(
                      label: 'All (${allReminders.length})',
                      selected: _selectedFilter == 'All',
                      onSelected: () => setState(() => _selectedFilter = 'All'),
                    ),
                    const SizedBox(width: 8),
                    FilterPill(
                      label: 'Overdue ($overdueCount)',
                      selected: _selectedFilter == 'Overdue',
                      onSelected: () => setState(() => _selectedFilter = 'Overdue'),
                    ),
                    const SizedBox(width: 8),
                    FilterPill(
                      label: 'Due Today ($dueTodayCount)',
                      selected: _selectedFilter == 'Due Today',
                      onSelected: () => setState(() => _selectedFilter = 'Due Today'),
                    ),
                    const SizedBox(width: 8),
                    FilterPill(
                      label: 'Due in 3 Days ($dueSoonCount)',
                      selected: _selectedFilter == 'Due in 3 Days',
                      onSelected: () => setState(() => _selectedFilter = 'Due in 3 Days'),
                    ),
                    const SizedBox(width: 8),
                    FilterPill(
                      label: 'Needs Scheduling ($unscheduledCount)',
                      selected: _selectedFilter == 'Needs Scheduling',
                      onSelected: () => setState(() => _selectedFilter = 'Needs Scheduling'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Reminder Items List
              if (service.isLoading || TeamService.instance.loading)
                _buildLoadingState()
              else if (filtered.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _buildReminderCard(filtered[index]),
                ),
            ],
          ),
        );

        if (widget.showCloseButton) {
          return CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): _handleClose,
            },
            child: Focus(
              autofocus: true,
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }

  Widget _buildSummaryBadge({
    required int count,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '$count $label',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading return check-up reminders...',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.task_alt_rounded, size: 36, color: const Color(0xFF10B981)),
          const SizedBox(height: 10),
          Text(
            _selectedFilter == 'All'
                ? 'No pending return check-ups found'
                : 'No reminders under "$_selectedFilter"',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'All patient return dates and appointment queues are currently up to date.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(FollowUpReminder reminder) {
    final statusColor = reminder.getStatusColor();
    final statusBg = reminder.getStatusBgColor();
    final statusLabel = reminder.getStatusLabel();
    final statusIcon = reminder.getStatusIcon();

    final isOverdue = reminder.getStatus() == FollowUpStatus.overdue;

    return Container(
      key: Key('reminder_card_${reminder.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue ? const Color(0xFFFCA5A5) : AppTheme.borderColor,
          width: isOverdue ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Patient Info + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: statusBg,
                child: Text(
                  reminder.patientName.isNotEmpty ? reminder.patientName[0].toUpperCase() : 'P',
                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            reminder.patientName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            reminder.patientMrn,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (reminder.patientPhone.isNotEmpty) ...[
                          Icon(Icons.phone_outlined, size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Text(reminder.patientPhone, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(width: 8),
                        ],
                        if (reminder.clinicBranch.isNotEmpty) ...[
                          Icon(Icons.location_on_outlined, size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              reminder.clinicBranch,
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Follow-up Details & Scheduling State
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.lightBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    reminder.followUpType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reminder.title,
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Scheduled status tag
                if (reminder.isScheduled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        const Text(
                          'Appointment Booked',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 12, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        const Text(
                          'Needs Scheduling',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Action Row: View Chart & Schedule Appointment Directly
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Quick Action 1: View Chart / Record
              OutlinedButton.icon(
                key: Key('btn_view_chart_${reminder.id}'),
                onPressed: () => _handleViewPatientChart(reminder),
                icon: const Icon(Icons.folder_shared_outlined, size: 14),
                label: const Text('View Chart', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: BorderSide(color: AppTheme.borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),

              // Quick Action 2: Schedule Appointment or View on Calendar
              if (!reminder.isScheduled)
                ElevatedButton.icon(
                  key: Key('btn_schedule_${reminder.id}'),
                  onPressed: () => _handleScheduleAppointment(reminder),
                  icon: const Icon(Icons.calendar_month_rounded, size: 14),
                  label: const Text('Schedule Visit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    visualDensity: VisualDensity.compact,
                    elevation: 0,
                  ),
                )
              else
                OutlinedButton.icon(
                  key: Key('btn_view_cal_${reminder.id}'),
                  onPressed: () {
                    if (widget.onOpenCalendar != null) {
                      widget.onOpenCalendar!(reminder.dueDate);
                    }
                  },
                  icon: const Icon(Icons.event_outlined, size: 14),
                  label: const Text('View on Calendar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF059669),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleViewPatientChart(FollowUpReminder reminder) {
    Patient? targetPatient = reminder.patient;
    if (targetPatient == null) {
      final all = PatientRepository.getAllPatients();
      try {
        targetPatient = all.firstWhere((p) =>
            p.id == reminder.patientId ||
            p.mrn == reminder.patientMrn ||
            p.fullName.toLowerCase() == reminder.patientName.toLowerCase());
      } catch (_) {}
    }

    if (targetPatient != null && widget.onSelectPatient != null) {
      widget.onSelectPatient!(targetPatient);
    }
  }

  void _handleScheduleAppointment(FollowUpReminder reminder) {
    Patient? targetPatient = reminder.patient;
    if (targetPatient == null) {
      final all = PatientRepository.getAllPatients();
      try {
        targetPatient = all.firstWhere((p) =>
            p.id == reminder.patientId ||
            p.mrn == reminder.patientMrn ||
            p.fullName.toLowerCase() == reminder.patientName.toLowerCase());
      } catch (_) {}
    }

    AddEventModal.show(
      context,
      initialDate: reminder.dueDate,
      initialPatient: targetPatient,
      initialTitle: reminder.title,
      initialEventType: 'Follow-up',
      initialLocation: reminder.clinicBranch,
      initialNotes: reminder.details,
    );
  }
}
