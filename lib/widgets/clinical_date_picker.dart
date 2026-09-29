import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'clinical_dropdown_field.dart';
import 'clinical_modal_picker.dart';

/// The app's one date picker (date of birth, event dates, ...), so every date
/// selection looks and behaves the same. Month and year are plain dropdowns
/// (no pop-up dialogs, no icons in the lists) and the previous/next arrows sit
/// on their own row underneath, so nothing shifts when the month changes.
Future<DateTime?> showClinicalDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final first = firstDate ?? DateTime(1900);
  final last = lastDate ?? DateTime(2040);

  DateTime clampedInitial = initialDate;
  if (clampedInitial.isBefore(first)) clampedInitial = first;
  if (clampedInitial.isAfter(last)) clampedInitial = last;

  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    builder: (context) => ClinicalDatePickerDialog(
      initialDate: clampedInitial,
      firstDate: first,
      lastDate: last,
    ),
  );
}

class ClinicalDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const ClinicalDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<ClinicalDatePickerDialog> createState() => _ClinicalDatePickerDialogState();
}

class _ClinicalDatePickerDialogState extends State<ClinicalDatePickerDialog> {
  late int _displayYear;
  late int _displayMonth;
  late DateTime _selectedDate;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekDayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayYear = widget.initialDate.year;
    _displayMonth = widget.initialDate.month;
  }

  void _previousMonth() {
    setState(() {
      if (_displayMonth == 1) {
        if (_displayYear > widget.firstDate.year) {
          _displayMonth = 12;
          _displayYear--;
        }
      } else {
        _displayMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_displayMonth == 12) {
        if (_displayYear < widget.lastDate.year) {
          _displayMonth = 1;
          _displayYear++;
        }
      } else {
        _displayMonth++;
      }
    });
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Compared by calendar day: DateTime.now() is later than a lastDate of "now"
  /// taken a moment earlier, which used to make Today a silent no-op.
  bool get _todayAllowed {
    final first = DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final last = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return !_today.isBefore(first) && !_today.isAfter(last);
  }

  /// Whether any day of [month] in [year] can be picked.
  bool _monthInRange(int year, int month) {
    final first = DateTime(widget.firstDate.year, widget.firstDate.month);
    final last = DateTime(widget.lastDate.year, widget.lastDate.month);
    final shown = DateTime(year, month);
    return !shown.isBefore(first) && !shown.isAfter(last);
  }

  /// The year list always has at least [_minYearRows] entries so it can be scrolled
  /// back and forward in time, even when the allowed range is narrow. Years outside
  /// the allowed range are shown greyed out and cannot be picked.
  static const int _minYearRows = 10;

  int get _yearListStart {
    var start = widget.firstDate.year;
    final missing = _minYearRows - (widget.lastDate.year - start + 1);
    if (missing > 0) start -= missing ~/ 2;
    return start;
  }

  int get _yearListEnd {
    var end = widget.lastDate.year;
    final missing = _minYearRows - (end - widget.firstDate.year + 1);
    if (missing > 0) end += missing - missing ~/ 2;
    return end;
  }

  bool _yearInRange(int year) => year >= widget.firstDate.year && year <= widget.lastDate.year;

  void _setYear(int year) {
    setState(() {
      _displayYear = year;
      // E.g. moving to the last allowed year while showing a month after the last date.
      if (!_monthInRange(year, _displayMonth)) {
        _displayMonth = year == widget.lastDate.year ? widget.lastDate.month : widget.firstDate.month;
      }
    });
  }

  bool get _canGoPrevious {
    if (_displayYear < widget.firstDate.year) return false;
    if (_displayYear == widget.firstDate.year && _displayMonth <= widget.firstDate.month) return false;
    return true;
  }

  bool get _canGoNext {
    if (_displayYear > widget.lastDate.year) return false;
    if (_displayYear == widget.lastDate.year && _displayMonth >= widget.lastDate.month) return false;
    return true;
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInCurrentMonth = _daysInMonth(_displayYear, _displayMonth);
    // Sunday is 0, Monday is 1, ..., Saturday is 6
    final firstDayOfWeek = DateTime(_displayYear, _displayMonth, 1).weekday % 7;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 10,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: month and year dropdowns.
              Row(
                children: [
                  Expanded(
                    child: ClinicalDropdownField<int>(
                      dense: true,
                      value: _displayMonth,
                      items: [
                        for (int m = 1; m <= 12; m++)
                          ClinicalPickerItem<int>(value: m, label: _monthNames[m - 1], enabled: _monthInRange(_displayYear, m)),
                      ],
                      onChanged: (m) => setState(() => _displayMonth = m),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 104,
                    child: ClinicalDropdownField<int>(
                      dense: true,
                      value: _displayYear,
                      items: [
                        for (int y = _yearListEnd; y >= _yearListStart; y--)
                          ClinicalPickerItem<int>(value: y, label: '$y', enabled: _yearInRange(y)),
                      ],
                      onChanged: _setYear,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Row 2: previous / next month arrows around the month being shown.
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.chevron_left, size: 22),
                      color: _canGoPrevious ? AppTheme.textPrimary : Colors.grey.shade300,
                      onPressed: _canGoPrevious ? _previousMonth : null,
                      tooltip: 'Previous month',
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_monthNames[_displayMonth - 1]} $_displayYear',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.chevron_right, size: 22),
                      color: _canGoNext ? AppTheme.textPrimary : Colors.grey.shade300,
                      onPressed: _canGoNext ? _nextMonth : null,
                      tooltip: 'Next month',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Weekday Headers: S M T W T F S
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _weekDayLabels.map((label) {
                  return SizedBox(
                    width: 38,
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: label == 'S' ? const Color(0xFFEF4444) : AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 6),
              const Divider(height: 1, color: AppTheme.borderColor),
              const SizedBox(height: 6),

              // Calendar Days Grid
              SizedBox(
                height: 230,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: 42, // 6 weeks * 7 days
                  itemBuilder: (context, index) {
                    final dayNumber = index - firstDayOfWeek + 1;
                    if (dayNumber < 1 || dayNumber > daysInCurrentMonth) {
                      return const SizedBox.shrink();
                    }

                    final cellDate = DateTime(_displayYear, _displayMonth, dayNumber);
                    final isSelected = cellDate.year == _selectedDate.year &&
                        cellDate.month == _selectedDate.month &&
                        cellDate.day == _selectedDate.day;
                    final isToday = cellDate.year == now.year &&
                        cellDate.month == now.month &&
                        cellDate.day == now.day;
                    final isDisabled = cellDate.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day)) ||
                        cellDate.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day));

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isDisabled
                            ? null
                            : () {
                                setState(() {
                                  _selectedDate = cellDate;
                                });
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : isToday
                                    ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isToday && !isSelected
                                ? Border.all(color: AppTheme.primaryBlue, width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : isDisabled
                                        ? Colors.grey.shade300
                                        : isToday
                                            ? AppTheme.primaryBlue
                                            : AppTheme.textPrimary,
                                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, color: AppTheme.borderColor),
              const SizedBox(height: 12),

              // Bottom Action Buttons
              Row(
                children: [
                  // Shortcut: Today
                  TextButton.icon(
                    onPressed: _todayAllowed
                        ? () {
                            setState(() {
                              _selectedDate = _today;
                              _displayYear = _today.year;
                              _displayMonth = _today.month;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.today, size: 16, color: AppTheme.primaryBlue),
                    label: const Text('Today', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),

                  const Spacer(),

                  // Cancel Button
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  ),

                  const SizedBox(width: 8),

                  // OK Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context, _selectedDate),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
