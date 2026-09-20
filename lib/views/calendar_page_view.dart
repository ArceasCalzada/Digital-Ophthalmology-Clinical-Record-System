import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../widgets/add_event_modal.dart';

class CalendarPageView extends StatefulWidget {
  final Function(Patient)? onSelectPatient;

  const CalendarPageView({super.key, this.onSelectPatient});

  @override
  State<CalendarPageView> createState() => _CalendarPageViewState();
}

class _CalendarPageViewState extends State<CalendarPageView> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  String _selectedTypeFilter = 'All';
  String _selectedLocationFilter = 'All';

  final List<String> _typeFilters = [
    'All',
    'Surgery',
    'Checkup',
    'Follow-up',
    'IOP Check',
    'Emergency',
    'Laser Procedure',
  ];

  final List<String> _locationFilters = [
    'All',
    'Davao',
    'Bukidnon',
    'General Santos',
    'OR Suite 3',
    'Exam Room 1',
    'Exam Room 2',
  ];

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      final now = DateTime.now();
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDate = now;
    });
  }

  Color _getEventTypeColor(String type) {
    switch (type) {
      case 'Surgery':
        return const Color(0xFFEF4444); // Red
      case 'Emergency':
        return const Color(0xFFD97706); // Amber
      case 'IOP Check':
        return const Color(0xFF10B981); // Emerald Green
      case 'Follow-up':
        return const Color(0xFF0284C7); // Sky Blue
      case 'Laser Procedure':
        return const Color(0xFF8B5CF6); // Purple
      case 'Checkup':
      default:
        return AppTheme.primaryBlue; // Primary Blue
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final repo = CalendarEventRepository();

    return ListenableBuilder(
      listenable: repo,
      builder: (context, child) {
        final allFilteredEvents = repo.getFilteredEvents(
          typeFilter: _selectedTypeFilter,
          locationFilter: _selectedLocationFilter,
        );

        final selectedDayEvents = repo.getFilteredEvents(
          typeFilter: _selectedTypeFilter,
          locationFilter: _selectedLocationFilter,
          specificDay: _selectedDate,
        );

        return Scaffold(
          backgroundColor: AppTheme.lightBg,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar with Quick Action
                    _buildPageHeader(context),
                    const SizedBox(height: 16),

                    // Categorization Filter Bar
                    _buildFilterSection(context),
                    const SizedBox(height: 20),

                    if (isNarrow) ...[
                      // Stacked view for smaller screens: Grid on top, Agenda below
                      _buildMonthCalendarCard(context, repo),
                      const SizedBox(height: 20),
                      _buildAgendaSection(context, repo, selectedDayEvents, allFilteredEvents),
                    ] else ...[
                      // Side-by-side view for Desktop / Large screens
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildMonthCalendarCard(context, repo),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: _buildAgendaSection(context, repo, selectedDayEvents, allFilteredEvents),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileHeader = constraints.maxWidth < 500;

        final titleWidget = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppTheme.primaryBlue,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clinical Calendar & Scheduling',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Patient appointments, surgeries & locations',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );

        final addButton = ElevatedButton.icon(
          onPressed: () => AddEventModal.show(context, initialDate: _selectedDate),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: isMobileHeader
              ? Column(
                  children: [
                    titleWidget,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: addButton),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 12),
                    addButton,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Type Filter Chips
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, size: 16, color: AppTheme.primaryBlue),
              const SizedBox(width: 6),
              const Text(
                'Type Filter:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _typeFilters.map((type) {
                      final isSelected = _selectedTypeFilter == type;
                      final chipColor = type == 'All' ? AppTheme.primaryBlue : _getEventTypeColor(type);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedTypeFilter = type);
                            }
                          },
                          selectedColor: chipColor,
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Location Filter Chips
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              const Text(
                'Location:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _locationFilters.map((loc) {
                      final isSelected = _selectedLocationFilter == loc;

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(loc),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedLocationFilter = loc);
                            }
                          },
                          selectedColor: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendarCard(BuildContext context, CalendarEventRepository repo) {
    final monthTitle = '${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}';
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Navigation controls for Month View
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary),
                    onPressed: _previousMonth,
                    tooltip: 'Previous Month',
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                  ),
                  Flexible(
                    child: Text(
                      monthTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary),
                    onPressed: _nextMonth,
                    tooltip: 'Next Month',
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _goToToday,
                icon: const Icon(Icons.today_rounded, size: 14),
                label: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  side: const BorderSide(color: AppTheme.primaryBlue),
                  foregroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Days of the week header
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) {
              final isWeekend = day == 'Sun' || day == 'Sat';
              return Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isWeekend ? const Color(0xFFEF4444) : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 8),

          // Month Days Grid
          _buildMonthGrid(context, repo, now),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(BuildContext context, CalendarEventRepository repo, DateTime now) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;

    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingEmptyDays = firstDayOfMonth.weekday % 7;

    final totalGridCells = ((leadingEmptyDays + daysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.9,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: totalGridCells,
      itemBuilder: (context, index) {
        final dayNumber = index - leadingEmptyDays + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }

        final cellDate = DateTime(year, month, dayNumber);
        final isToday = cellDate.year == now.year && cellDate.month == now.month && cellDate.day == now.day;
        final isSelected = cellDate.year == _selectedDate.year && cellDate.month == _selectedDate.month && cellDate.day == _selectedDate.day;

        final dayEvents = repo.getFilteredEvents(
          typeFilter: _selectedTypeFilter,
          locationFilter: _selectedLocationFilter,
          specificDay: cellDate,
        );

        return InkWell(
          onTap: () {
            setState(() {
              _selectedDate = cellDate;
            });
            // Seamless event creation: double-tap or click directly on any date block opens "Add Event" modal
            AddEventModal.show(context, initialDate: cellDate);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.12)
                  : (isToday ? const Color(0xFFEFF6FF) : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryBlue
                    : (isToday ? AppTheme.primaryBlue.withValues(alpha: 0.5) : AppTheme.borderColor),
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isToday ? AppTheme.primaryBlue : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isToday ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (dayEvents.isNotEmpty)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _getEventTypeColor(dayEvents.first.eventType),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),

                // Event preview badges
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dayEvents.length > 2 ? 2 : dayEvents.length,
                    itemBuilder: (context, idx) {
                      final evt = dayEvents[idx];
                      final badgeColor = _getEventTypeColor(evt.eventType);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border(left: BorderSide(color: badgeColor, width: 2.5)),
                        ),
                        child: Text(
                          evt.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgendaSection(
    BuildContext context,
    CalendarEventRepository repo,
    List<CalendarEvent> selectedDayEvents,
    List<CalendarEvent> allFilteredEvents,
  ) {
    final selectedDateFormatted = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.format_list_bulleted_rounded, color: AppTheme.primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Agenda for $selectedDateFormatted',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${selectedDayEvents.length} Events',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (selectedDayEvents.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  const Icon(Icons.event_available_rounded, size: 36, color: AppTheme.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    'No appointments or surgeries for $selectedDateFormatted.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => AddEventModal.show(context, initialDate: _selectedDate),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Schedule Event on This Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedDayEvents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final evt = selectedDayEvents[idx];
                return _buildAgendaItemCard(context, evt, repo);
              },
            ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 14),

          // Overall Chronological Upcoming Schedule
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Upcoming Master Schedule',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total: ${allFilteredEvents.length}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allFilteredEvents.length > 5 ? 5 : allFilteredEvents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final evt = allFilteredEvents[idx];
              final dateStr = '${evt.dateTime.year}-${evt.dateTime.month.toString().padLeft(2, '0')}-${evt.dateTime.day.toString().padLeft(2, '0')}';
              final timeStr = TimeOfDay.fromDateTime(evt.dateTime).format(context);
              final tagColor = _getEventTypeColor(evt.eventType);

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 34,
                      decoration: BoxDecoration(
                        color: tagColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            evt.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: evt.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
                              decoration: evt.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$dateStr • $timeStr • ${evt.patientName} (${evt.location})',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        evt.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: evt.isCompleted ? const Color(0xFF10B981) : AppTheme.textSecondary,
                        size: 18,
                      ),
                      onPressed: () => repo.toggleEventStatus(evt.id),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaItemCard(BuildContext context, CalendarEvent evt, CalendarEventRepository repo) {
    final tagColor = _getEventTypeColor(evt.eventType);
    final formattedTime = TimeOfDay.fromDateTime(evt.dateTime).format(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        evt.eventType.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tagColor, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                evt.location,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formattedTime,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            evt.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: evt.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
              decoration: evt.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${evt.patientName}${evt.patientId != null ? ' (${evt.patientId})' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (evt.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: ${evt.notes}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
            ),
          ],

          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.alarm, size: 13, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Reminder: ${evt.reminderMinutes}m before',
                        style: const TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      evt.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: evt.isCompleted ? const Color(0xFF10B981) : AppTheme.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => repo.toggleEventStatus(evt.id),
                    tooltip: 'Toggle status',
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                    onPressed: () => repo.deleteEvent(evt.id),
                    tooltip: 'Delete event',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
