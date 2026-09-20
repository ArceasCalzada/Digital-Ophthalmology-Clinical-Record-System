import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/clinical_notification.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import 'clinical_modal_picker.dart';

class AddEventModal extends StatefulWidget {
  final DateTime? initialDate;

  const AddEventModal({super.key, this.initialDate});

  static Future<void> show(BuildContext context, {DateTime? initialDate}) async {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: AddEventModal(initialDate: initialDate),
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AddEventModal(initialDate: initialDate),
          ),
        ),
      );
    }
  }

  @override
  State<AddEventModal> createState() => _AddEventModalState();
}

class _AddEventModalState extends State<AddEventModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String _selectedEventType = 'Checkup';
  String _selectedLocation = 'Davao';
  int _selectedReminderMinutes = 30;
  Patient? _selectedPatient;

  final List<String> _eventTypes = [
    'Checkup',
    'Surgery',
    'Follow-up',
    'IOP Check',
    'Emergency',
    'Laser Procedure',
  ];

  final List<String> _locations = [
    'Davao',
    'Bukidnon',
    'General Santos',
    'OR Suite 3',
    'Exam Room 1',
    'Exam Room 2',
  ];

  final List<Map<String, dynamic>> _reminderOptions = [
    {'label': '15 minutes before', 'value': 15},
    {'label': '30 minutes before', 'value': 30},
    {'label': '1 hour before', 'value': 60},
    {'label': '1 day before', 'value': 1440},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
    final patients = PatientRepository.getAllPatients();
    if (patients.isNotEmpty) {
      _selectedPatient = patients.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              surface: AppTheme.cardBg,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              surface: AppTheme.cardBg,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _saveEvent() {
    if (_formKey.currentState?.validate() ?? false) {
      final title = _titleController.text.trim();
      final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final newEvent = CalendarEvent(
        id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        title: title.isEmpty
            ? '$_selectedEventType — ${_selectedPatient?.fullName ?? 'Patient'}'
            : title,
        eventType: _selectedEventType,
        location: _selectedLocation,
        dateTime: dt,
        patientName: _selectedPatient?.fullName ?? 'Scheduled Patient',
        patientId: _selectedPatient?.mrn,
        reminderMinutes: _selectedReminderMinutes,
        notes: _notesController.text.trim(),
      );

      CalendarEventRepository().addEvent(newEvent);

      // Trigger notification for scheduled reminder
      ClinicalNotificationRepository().addNotification(
        ClinicalNotification(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Event Scheduled: ${newEvent.title}',
          message: 'Appointment set for ${newEvent.patientName} at ${newEvent.location} on ${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(dt).format(context)}.',
          category: newEvent.eventType == 'Surgery' || newEvent.eventType == 'Emergency' ? 'Urgent Alert' : 'Reminder',
          severity: newEvent.eventType == 'Surgery' || newEvent.eventType == 'Emergency' ? NotificationSeverity.urgent : NotificationSeverity.info,
          timestamp: DateTime.now(),
          patientName: newEvent.patientName,
          patientId: newEvent.patientId,
        ),
      );

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Event "${newEvent.title}" scheduled successfully!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final allPatients = PatientRepository.getAllPatients();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mobile Drag Handle Indicator
              if (isMobile)
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

              // Title Header & Close Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
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
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Clinical Event',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Schedule appointment or procedure',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Event Title Field
              const Text(
                'Event Title',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Glaucoma Consultation & IOP Check',
                  prefixIcon: Icon(Icons.event_note, color: AppTheme.primaryBlue, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              // Select Patient Dropdown
              // Select Patient Modal Field
              ClinicalModalPickerField<Patient>(
                label: 'Patient Name',
                placeholder: 'Select patient...',
                displayText: _selectedPatient != null ? '${_selectedPatient!.fullName} (${_selectedPatient!.mrn})' : '',
                icon: Icons.person_rounded,
                onTap: () async {
                  final items = allPatients.map((p) {
                    return ClinicalPickerItem<Patient>(
                      value: p,
                      label: p.fullName,
                      subtitle: '${p.mrn} • ${p.gender}, ${p.age} yrs',
                      icon: Icons.person_rounded,
                      iconColor: AppTheme.primaryBlue,
                    );
                  }).toList();

                  final selected = await showClinicalModalPicker<Patient>(
                    context: context,
                    title: 'Select Patient for Appointment',
                    enableSearch: true,
                    searchHint: 'Search patient by name or MRN...',
                    selectedValue: _selectedPatient,
                    items: items,
                  );

                  if (selected != null) {
                    setState(() => _selectedPatient = selected);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Event Type & Location (Row on wider screens, stacked on narrow mobile)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;
                  final typeField = ClinicalModalPickerField<String>(
                    label: 'Event Type',
                    placeholder: 'Select event type',
                    displayText: _selectedEventType,
                    icon: Icons.event_rounded,
                    onTap: () async {
                      final items = _eventTypes.map((t) {
                        return ClinicalPickerItem<String>(
                          value: t,
                          label: t,
                          icon: Icons.calendar_month_rounded,
                          iconColor: AppTheme.primaryBlue,
                        );
                      }).toList();

                      final selected = await showClinicalModalPicker<String>(
                        context: context,
                        title: 'Select Event Type',
                        selectedValue: _selectedEventType,
                        items: items,
                      );

                      if (selected != null) {
                        setState(() => _selectedEventType = selected);
                      }
                    },
                  );

                  final locationField = ClinicalModalPickerField<String>(
                    label: 'Location',
                    placeholder: 'Select location',
                    displayText: _selectedLocation,
                    icon: Icons.location_on_rounded,
                    onTap: () async {
                      final items = _locations.map((loc) {
                        return ClinicalPickerItem<String>(
                          value: loc,
                          label: loc,
                          icon: Icons.local_hospital_rounded,
                          iconColor: const Color(0xFF10B981),
                        );
                      }).toList();

                      final selected = await showClinicalModalPicker<String>(
                        context: context,
                        title: 'Select Location / Room',
                        selectedValue: _selectedLocation,
                        items: items,
                      );

                      if (selected != null) {
                        setState(() => _selectedLocation = selected);
                      }
                    },
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        typeField,
                        const SizedBox(height: 16),
                        locationField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: typeField),
                      const SizedBox(width: 12),
                      Expanded(child: locationField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Date & Time Touch Pickers
              const Text(
                'Schedule Date & Time',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryBlue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 18, color: AppTheme.primaryBlue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedTime.format(context),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reminder Alert Modal Field
              ClinicalModalPickerField<int>(
                label: 'Notification Reminder Alert',
                placeholder: 'Select reminder time',
                displayText: _reminderOptions.firstWhere((r) => r['value'] == _selectedReminderMinutes)['label'] as String,
                icon: Icons.notifications_active_rounded,
                onTap: () async {
                  final items = _reminderOptions.map((r) {
                    return ClinicalPickerItem<int>(
                      value: r['value'] as int,
                      label: r['label'] as String,
                      icon: Icons.alarm_rounded,
                      iconColor: const Color(0xFFD97706),
                    );
                  }).toList();

                  final selected = await showClinicalModalPicker<int>(
                    context: context,
                    title: 'Select Notification Reminder',
                    selectedValue: _selectedReminderMinutes,
                    items: items,
                  );

                  if (selected != null) {
                    setState(() => _selectedReminderMinutes = selected);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Notes Input
              const Text(
                'Clinical Notes / Reason for Visit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Add clinical instructions or special equipment requests...',
                ),
              ),
              const SizedBox(height: 24),

              // Save Action Button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saveEvent,
                  icon: const Icon(Icons.check_rounded, size: 22),
                  label: const Text(
                    'Confirm & Save Event',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
