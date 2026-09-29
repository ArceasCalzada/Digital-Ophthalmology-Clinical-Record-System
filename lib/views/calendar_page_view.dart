import '../widgets/clinic_dialogs.dart';
import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/patient.dart';
import '../services/event_options_store.dart';
import '../theme/app_theme.dart';
import '../widgets/add_event_modal.dart';
import '../widgets/filter_pill.dart';
import '../widgets/page_header.dart';

/// "Wed, Sep 30 (Tomorrow)": weekday, month and day, then how far away it is.
/// With [long] it reads "Wednesday, Sep. 30 (Tomorrow)". The year is only added
/// when it is not the current year ("Thu, Jan 7, 2027 (3 months from now)").
/// Days are compared by calendar date, so 11 PM tonight is still "Today".
String formatScheduleDate(DateTime date, {DateTime? now, bool long = false}) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const longWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final today = now ?? DateTime.now();

  final weekday = (long ? longWeekdays : weekdays)[date.weekday - 1];
  // Short months that are complete words ("May") take no period.
  final month = long && date.month != 5 ? '${months[date.month - 1]}.' : months[date.month - 1];
  final year = date.year != today.year ? ', ${date.year}' : '';
  return '$weekday, $month ${date.day}$year (${_relativeDay(date, today)})';
}

/// How far [date] is from [today]: exact days for the first week, then whole
/// weeks, whole calendar months and whole years ("2 weeks from now").
String _relativeDay(DateTime date, DateTime today) {
  final days = DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(today.year, today.month, today.day))
      .inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days == -1) return 'Yesterday';

  final ahead = days > 0;
  final from = ahead ? today : date;
  final to = ahead ? date : today;
  final months = (to.year - from.year) * 12 + to.month - from.month - (to.day < from.day ? 1 : 0);

  String amount(int n, String unit) => '$n ${n == 1 ? unit : '${unit}s'}';
  final String span;
  if (months >= 12) {
    span = amount(months ~/ 12, 'year');
  } else if (months >= 1) {
    span = amount(months, 'month');
  } else if (days.abs() >= 7) {
    span = amount(days.abs() ~/ 7, 'week');
  } else {
    span = amount(days.abs(), 'day');
  }
  return ahead ? '$span from now' : '$span ago';
}

class CalendarPageView extends StatefulWidget {
  final Function(Patient)? onSelectPatient;

  /// The day to show selected when the page opens; today when null.
  final DateTime? initialDate;

  const CalendarPageView({super.key, this.onSelectPatient, this.initialDate});

  @override
  State<CalendarPageView> createState() => _CalendarPageViewState();
}

class _CalendarPageViewState extends State<CalendarPageView> {
  late DateTime _focusedMonth = widget.initialDate ?? DateTime.now();
  late DateTime _selectedDate = widget.initialDate ?? DateTime.now();
  String _selectedTypeFilter = 'All';
  String _selectedLocationFilter = 'All';
  bool _filtersExpanded = false; // most people never filter, so it starts collapsed

  // The filter choices follow the clinic's own lists (edited from the Add Event dropdowns).
  List<String> get _typeFilters => ['All', ...EventOptionsStore.instance.types];
  List<String> get _locationFilters => ['All', ...EventOptionsStore.instance.locations];

  /// Which way the month grid slides: 1 when moving to a later month (new grid
  /// rises from below), -1 when moving to an earlier one (new grid drops from above).
  int _slideDirection = 1;

  /// Moves the calendar to the month containing [target], optionally selecting [select].
  void _showMonth(DateTime target, {DateTime? select}) {
    final month = DateTime(target.year, target.month, 1);
    setState(() {
      if (month.isAfter(_focusedMonth)) {
        _slideDirection = 1;
      } else if (month.isBefore(_focusedMonth)) {
        _slideDirection = -1;
      }
      _focusedMonth = month;
      if (select != null) _selectedDate = select;
    });
  }

  /// Adds an appointment on the selected day, asking for a clinic first if there is none.
  Future<void> _addEvent() async {
    if (!await ensureClinic(context) || !mounted) return;
    await AddEventModal.show(context, initialDate: _selectedDate);
  }

  void _previousMonth() => _showMonth(DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1));

  void _nextMonth() => _showMonth(DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1));

  void _goToToday() {
    final now = DateTime.now();
    _showMonth(now, select: now);
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
      listenable: Listenable.merge([repo, EventOptionsStore.instance]),
      builder: (context, child) {
        // A filter whose type or location was just deleted goes back to showing everything.
        if (!_typeFilters.contains(_selectedTypeFilter)) _selectedTypeFilter = 'All';
        if (!_locationFilters.contains(_selectedLocationFilter)) _selectedLocationFilter = 'All';

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
                padding: const EdgeInsets.all(PageHeader.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar with Quick Action
                    _buildPageHeader(context),

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
    return PageHeader(
      title: 'Clinical Calendar & Scheduling',
      subtitle: 'Patient appointments, surgeries & locations',
      action: ElevatedButton.icon(
        onPressed: () => _addEvent(),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  /// Collapsible "Filters" card. When collapsed it still says which filters are
  /// active, so a hidden filter never silently hides events.
  Widget _buildFilterSection(BuildContext context) {
    final active = [
      if (_selectedTypeFilter != 'All') _selectedTypeFilter,
      if (_selectedLocationFilter != 'All') _selectedLocationFilter,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  if (active.isNotEmpty && !_filtersExpanded) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        active.join(' • '),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Icon(
                    _filtersExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_filtersExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _buildFilterChips(context),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pills wrap onto the next line instead of scrolling out of the card.
          // Event Type Filter Chips
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text(
                    'Type Filter:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                for (final type in _typeFilters)
                  FilterPill(
                    label: type,
                    selected: _selectedTypeFilter == type,
                    selectedColor: type == 'All' ? AppTheme.primaryBlue : _getEventTypeColor(type),
                    onSelected: () => setState(() => _selectedTypeFilter = type),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Location Filter Chips
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text(
                    'Location:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                for (final loc in _locationFilters)
                  FilterPill(
                    label: loc,
                    selected: _selectedLocationFilter == loc,
                    selectedColor: const Color(0xFF10B981),
                    onSelected: () => setState(() => _selectedLocationFilter = loc),
                  ),
              ],
            ),
          ),
        ],
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
          LayoutBuilder(builder: (context, constraints) {
            final monthNav = Row(
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
              );
            final todayButton = OutlinedButton.icon(
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
              );

            // Month centred with Today at the right; on a narrow card there is no
            // room for both, so they wrap instead.
            if (constraints.maxWidth < 420) {
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [monthNav, todayButton],
              );
            }
            return Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                monthNav,
                Expanded(child: Align(alignment: Alignment.centerRight, child: todayButton)),
              ],
            );
          }),
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

          // Month Days Grid: slides up when going forward, down when going back
          ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 550), // slow enough to follow which way the month moved
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final isIncoming = child.key == ValueKey('${_focusedMonth.year}-${_focusedMonth.month}');
                // The outgoing grid runs its animation in reverse, so it exits toward the
                // opposite side from where the incoming one enters.
                final offset = Tween<Offset>(
                  begin: Offset(0, isIncoming ? 0.12 * _slideDirection : -0.12 * _slideDirection),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey('${_focusedMonth.year}-${_focusedMonth.month}'),
                child: _buildMonthGrid(context, repo, now),
              ),
            ),
          ),
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
        final rawDay = index - leadingEmptyDays + 1;
        final isOutsideMonth = rawDay < 1 || rawDay > daysInMonth;

        // DateTime rolls over out-of-range days, so a day of 0 is the last day of the
        // previous month and daysInMonth + 1 is the 1st of the next.
        final cellDate = DateTime(year, month, rawDay);
        final dayNumber = cellDate.day;
        final isToday = cellDate.year == now.year && cellDate.month == now.month && cellDate.day == now.day;
        final isSelected = cellDate.year == _selectedDate.year && cellDate.month == _selectedDate.month && cellDate.day == _selectedDate.day;

        final dayEvents = repo.getFilteredEvents(
          typeFilter: _selectedTypeFilter,
          locationFilter: _selectedLocationFilter,
          specificDay: cellDate,
        );

        return InkWell(
          onTap: () {
            // Selecting a day shows its timeline (agenda) first, where events can be edited
            // or deleted; new events are added from there or via "Add Event".
            // A grayed-out day from a neighbouring month also switches to that month.
            if (isOutsideMonth) {
              _showMonth(cellDate, select: cellDate);
            } else {
              setState(() {
                _selectedDate = cellDate;
              });
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Opacity(
            opacity: isOutsideMonth ? 0.5 : 1,
            child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.12)
                  : (isOutsideMonth
                      ? const Color(0xFFF8FAFC)
                      : (isToday ? const Color(0xFFEFF6FF) : Colors.white)),
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
                // A Stack, not a Row: on a phone the cell is narrower than the number
                // plus the dot, and a Row would overflow.
                SizedBox(
                  height: 20,
                  child: Stack(
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
                        Positioned(
                          top: 7,
                          right: 0,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _getEventTypeColor(dayEvents.first.eventType),
                              shape: BoxShape.circle,
                            ),
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
    final selectedDateFormatted = formatScheduleDate(_selectedDate, long: true);

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
          // Title + events for the selected day. Picking another date cross-fades
          // to the new day while the card grows or shrinks, so it is easy to follow.
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: SizedBox(
                key: ValueKey('agenda-${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}'),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agenda for $selectedDateFormatted',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    if (selectedDayEvents.isEmpty)
                      // The heading already names the day, so no extra "nothing scheduled" text.
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
                            const Text(
                              'No events for this date',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _addEvent(),
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
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 14),

          // Overall Chronological Upcoming Schedule
          const Text(
            'Upcoming Master Schedule',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allFilteredEvents.length > 5 ? 5 : allFilteredEvents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final evt = allFilteredEvents[idx];
              final dateStr = formatScheduleDate(evt.dateTime);
              final timeStr = TimeOfDay.fromDateTime(evt.dateTime).format(context);
              // Only today's events keep their colour, so what is coming next stands out.
              final now = DateTime.now();
              final isToday = evt.dateTime.year == now.year && evt.dateTime.month == now.month && evt.dateTime.day == now.day;
              final tagColor = isToday ? _getEventTypeColor(evt.eventType) : const Color(0xFFCBD5E1);

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                // Tapping a row opens it for editing (same as the agenda cards).
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => AddEventModal.show(context, event: evt),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
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
                                    color: evt.isCompleted || !isToday ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    decoration: evt.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$dateStr • $timeStr • ${evt.patientName}${evt.location.isEmpty ? '' : ' (${evt.location})'}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
      ),
      // The whole card is the edit button: tapping it opens the event for editing.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => AddEventModal.show(context, event: evt),
          child: Padding(
            padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Tags on the left, the time in the upper-right corner.
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Event type and location are optional, so their tags only show when set.
                    if (evt.eventType.isNotEmpty)
                    Flexible(
                      child: Container(
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
                    ),
                    if (evt.eventType.isNotEmpty && evt.location.isNotEmpty) const SizedBox(width: 6),
                    if (evt.location.isNotEmpty)
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
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
            const SizedBox(height: 10),
            Text(
              'Notes: ${evt.notes}',
              style: const TextStyle(fontSize: 12, height: 1.4, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
          ),
        ),
      ),
    );
  }
}
