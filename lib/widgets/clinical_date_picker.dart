import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a clean, jitter-free clinical calendar picker modal.
/// Eliminates the wide side-panel and ensures all month names (up to "September")
/// and year selectors remain in fixed, static positions without jumping.
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
              // Static Top Header: Month Dropdown + Year Dropdown + Prev/Next Arrows
              // With fixed width containers so nothing shifts when month/year changes!
              Row(
                children: [
                  // Fixed Month Selector
                  Container(
                    width: 125,
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _displayMonth,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue, size: 20),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        items: List.generate(12, (index) {
                          final monthNum = index + 1;
                          return DropdownMenuItem<int>(
                            value: monthNum,
                            child: Text(
                              _monthNames[index],
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                        onChanged: (newMonth) {
                          if (newMonth != null) {
                            setState(() {
                              _displayMonth = newMonth;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Fixed Year Selector
                  Container(
                    width: 86,
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _displayYear.clamp(widget.firstDate.year, widget.lastDate.year),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue, size: 20),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        items: [
                          for (int y = widget.lastDate.year; y >= widget.firstDate.year; y--)
                            DropdownMenuItem<int>(
                              value: y,
                              child: Text('$y'),
                            ),
                        ],
                        onChanged: (newYear) {
                          if (newYear != null) {
                            setState(() {
                              _displayYear = newYear;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Previous Month Button
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

                  // Next Month Button
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
                    final isDisabled = cellDate.isBefore(widget.firstDate) || cellDate.isAfter(widget.lastDate);

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
                    onPressed: () {
                      final today = DateTime.now();
                      if (!today.isBefore(widget.firstDate) && !today.isAfter(widget.lastDate)) {
                        setState(() {
                          _selectedDate = today;
                          _displayYear = today.year;
                          _displayMonth = today.month;
                        });
                      }
                    },
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
