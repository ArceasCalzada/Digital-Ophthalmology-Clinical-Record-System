import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// The app's one time picker, so every time selection looks and behaves the same
/// (and matches the date picker). Instead of a clock dial it is plain input: the
/// hour and minute are text fields you can type into, each with an up and a down
/// button to nudge the number (hold to keep nudging), and AM/PM is a toggle beside
/// them. Typing 13-23 in the hour field is read as a 24-hour time.
Future<TimeOfDay?> showClinicalTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    barrierDismissible: true,
    builder: (context) => ClinicalTimePickerDialog(initialTime: initialTime),
  );
}

class ClinicalTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;

  const ClinicalTimePickerDialog({super.key, required this.initialTime});

  @override
  State<ClinicalTimePickerDialog> createState() => _ClinicalTimePickerDialogState();
}

class _ClinicalTimePickerDialogState extends State<ClinicalTimePickerDialog> {
  late int _hour12; // 1..12
  late int _minute; // 0..59
  late bool _isPm;

  final _hourController = TextEditingController();
  final _minuteController = TextEditingController();
  final _hourFocus = FocusNode();
  final _minuteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _apply(widget.initialTime);
    _wireField(_hourFocus, _hourController, _commitHour, () => _nudgeHour(1), () => _nudgeHour(-1));
    _wireField(_minuteFocus, _minuteController, _commitMinute, () => _nudgeMinute(1), () => _nudgeMinute(-1));
  }

  /// Select-all on focus (so typing replaces the number), commit on blur, and the
  /// up/down arrow keys nudge the value like the buttons do.
  void _wireField(FocusNode focus, TextEditingController controller, VoidCallback commit, VoidCallback up, VoidCallback down) {
    focus.addListener(() {
      if (focus.hasFocus) {
        controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
      } else {
        commit();
      }
    });
    focus.onKeyEvent = (node, event) {
      if (event is KeyUpEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        up();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        down();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _apply(TimeOfDay t) {
    _hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    _minute = t.minute;
    _isPm = t.period == DayPeriod.pm;
    _syncFields();
  }

  void _syncFields() {
    _hourController.text = '$_hour12';
    _minuteController.text = _two(_minute);
  }

  /// Reads what was typed in the hour field. 13-23 means a 24-hour time (1-11 PM),
  /// 0 means 12 AM; anything else outside 1-12 is clamped; empty keeps the old hour.
  void _commitHour() {
    final typed = int.tryParse(_hourController.text);
    if (!mounted) return;
    setState(() {
      if (typed != null) {
        if (typed == 0) {
          _hour12 = 12;
          _isPm = false;
        } else if (typed > 12) {
          final h = typed > 23 ? 23 : typed;
          _hour12 = h - 12;
          _isPm = true;
        } else {
          _hour12 = typed;
        }
      }
      _hourController.text = '$_hour12';
    });
  }

  void _commitMinute() {
    final typed = int.tryParse(_minuteController.text);
    if (!mounted) return;
    setState(() {
      if (typed != null) _minute = typed.clamp(0, 59);
      _minuteController.text = _two(_minute);
    });
  }

  void _nudgeHour(int delta) {
    _commitHour();
    setState(() {
      _hour12 = (_hour12 - 1 + delta) % 12 + 1; // wraps 12 -> 1 and 1 -> 12
      _hourController.text = '$_hour12';
    });
  }

  void _nudgeMinute(int delta) {
    _commitMinute();
    setState(() {
      _minute = (_minute + delta) % 60; // wraps 59 -> 0 and 0 -> 59, the hour is unchanged
      _minuteController.text = _two(_minute);
    });
  }

  TimeOfDay get _time => TimeOfDay(hour: (_hour12 % 12) + (_isPm ? 12 : 0), minute: _minute);

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 10,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select time',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),

              // hour : minute, then AM/PM stacked beside them, centred as one group.
              // FittedBox shrinks the whole group on a very narrow screen instead of overflowing.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _TimeStepper(
                      fieldKey: const ValueKey('hour-field'),
                      upKey: const ValueKey('hour-up'),
                      downKey: const ValueKey('hour-down'),
                      controller: _hourController,
                      focusNode: _hourFocus,
                      onUp: () => _nudgeHour(1),
                      onDown: () => _nudgeHour(-1),
                      onSubmitted: _commitHour,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(':', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ),
                    _TimeStepper(
                      fieldKey: const ValueKey('minute-field'),
                      upKey: const ValueKey('minute-up'),
                      downKey: const ValueKey('minute-down'),
                      controller: _minuteController,
                      focusNode: _minuteFocus,
                      onUp: () => _nudgeMinute(1),
                      onDown: () => _nudgeMinute(-1),
                      onSubmitted: _commitMinute,
                    ),
                    const SizedBox(width: 18),
                    _PeriodToggle(isPm: _isPm, onChanged: (pm) => setState(() => _isPm = pm)),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppTheme.borderColor),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      // Take whatever is still being typed.
                      _commitHour();
                      _commitMinute();
                      Navigator.pop(context, _time);
                    },
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),            ],
          ),
        ),
      ),
    );
  }
}
/// A two-digit number field with an up button above it and a down button below.
class _TimeStepper extends StatelessWidget {
  final Key fieldKey;
  final Key upKey;
  final Key downKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onSubmitted;

  const _TimeStepper({
    required this.fieldKey,
    required this.upKey,
    required this.downKey,
    required this.controller,
    required this.focusNode,
    required this.onUp,
    required this.onDown,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NudgeButton(key: upKey, icon: Icons.keyboard_arrow_up_rounded, onNudge: onUp),
        SizedBox(
          width: 80,
          child: TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppTheme.lightBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: border(AppTheme.borderColor),
              enabledBorder: border(AppTheme.borderColor),
              focusedBorder: border(AppTheme.primaryBlue, 1.8),
            ),
          ),
        ),
        _NudgeButton(key: downKey, icon: Icons.keyboard_arrow_down_rounded, onNudge: onDown),
      ],
    );
  }
}
/// An arrow button that nudges once when pressed and keeps nudging, faster the
/// longer it is held, until it is released.
class _NudgeButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onNudge;

  const _NudgeButton({super.key, required this.icon, required this.onNudge});

  @override
  State<_NudgeButton> createState() => _NudgeButtonState();
}

class _NudgeButtonState extends State<_NudgeButton> {
  static const _holdDelay = Duration(milliseconds: 400);
  static const _slowRepeat = Duration(milliseconds: 120);
  static const _fastRepeat = Duration(milliseconds: 50);
  static const _slowRepeats = 8; // repeats at the slow rate before speeding up

  Timer? _timer;
  int _repeats = 0;

  void _start() {
    _stop();
    widget.onNudge();
    _repeats = 0;
    _timer = Timer(_holdDelay, _repeat);
  }

  void _repeat() {
    widget.onNudge();
    _repeats++;
    _timer = Timer(_repeats < _slowRepeats ? _slowRepeat : _fastRepeat, _repeat);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 20,
      onTapDown: (_) => _start(),
      onTap: _stop,
      onTapCancel: _stop,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(widget.icon, color: AppTheme.primaryBlue),
      ),
    );
  }
}
/// AM over PM segmented toggle, stacked so it sits beside the time as tall as the field.
class _PeriodToggle extends StatelessWidget {
  final bool isPm;
  final ValueChanged<bool> onChanged;
  const _PeriodToggle({required this.isPm, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget segment(String text, bool pm) {
      final selected = isPm == pm;
      return InkWell(
        onTap: () => onChanged(pm),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [segment('AM', false), const SizedBox(height: 4), segment('PM', true)]),
    );
  }
}