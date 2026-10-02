import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/clinical_notification.dart';
import '../models/patient.dart';
import '../services/event_options_store.dart';
import '../services/reminder_settings_store.dart';
import '../theme/app_theme.dart';
import 'clinical_date_picker.dart';
import 'clinical_dropdown_field.dart';
import 'clinical_modal_picker.dart';
import 'clinical_time_picker.dart';
import 'required_text_form_field.dart';
import 'field_label.dart';
import 'success_modal.dart';

class AddEventModal extends StatefulWidget {
  final DateTime? initialDate;

  /// When set, the modal edits this event instead of creating a new one.
  final CalendarEvent? event;

  const AddEventModal({super.key, this.initialDate, this.event});

  static Future<void> show(BuildContext context, {DateTime? initialDate, CalendarEvent? event}) async {
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
          child: AddEventModal(initialDate: initialDate, event: event),
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: AddEventModal(initialDate: initialDate, event: event),
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
  // Not assumed: the user picks these, and both are optional.
  String? _selectedEventType;
  String? _selectedLocation;
  Patient? _selectedPatient;

  final _options = EventOptionsStore.instance;


  @override
  void initState() {
    super.initState();
    final editing = widget.event;
    final patients = PatientRepository.getAllPatients();
    if (editing != null) {
      _titleController.text = editing.title;
      _notesController.text = editing.notes;
      _selectedDate = editing.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(editing.dateTime);
      _selectedEventType = editing.eventType.isEmpty ? null : editing.eventType;
      _selectedLocation = editing.location.isEmpty ? null : editing.location;
      for (final p in patients) {
        if (p.mrn == editing.patientId) {
          _selectedPatient = p;
          break;
        }
      }
      return;
    }
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(Duration(hours: 1)));
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

  /// "None" (always offered, so an optional choice can be cleared) plus the clinic's list.
  /// An event saved with a name that has since been deleted still shows it when edited.
  List<ClinicalPickerItem<String>> _choices(List<String> saved, String? selected) {
    return [
      ClinicalPickerItem<String>(value: '', label: 'None', removable: false),
      for (final name in saved) ClinicalPickerItem<String>(value: name, label: name),
      if (selected != null && !saved.contains(selected))
        ClinicalPickerItem<String>(value: selected, label: selected, removable: false),
    ];
  }

  Future<void> _pickDate() async {
    // Widen the range so an existing event outside the default window can still be edited.
    final now = DateTime.now();
    var firstDate = DateTime(now.year - 5, 1, 1);
    var lastDate = DateTime(now.year + 10, 12, 31);
    if (_selectedDate.isBefore(firstDate)) firstDate = _selectedDate;
    if (_selectedDate.isAfter(lastDate)) lastDate = _selectedDate;

    // The app-wide date picker, so event dates look like every other date selection.
    final picked = await showClinicalDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    // The app-wide time picker, so event times look like every other time selection.
    final picked = await showClinicalTimePicker(context: context, initialTime: _selectedTime);
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

      final editing = widget.event;
      final newEvent = CalendarEvent(
        id: editing?.id ?? 'evt-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        eventType: _selectedEventType ?? '',
        location: _selectedLocation ?? '',
        dateTime: dt,
        patientName: _selectedPatient?.fullName ?? editing?.patientName ?? 'Scheduled Patient',
        patientId: _selectedPatient?.mrn ?? editing?.patientId,
        // Not asked per event: a new one takes the reminder time chosen in Settings,
        // and an edited one keeps the time it was saved with.
        reminderMinutes: editing?.reminderMinutes ?? ReminderSettingsStore.instance.minutesBefore,
        notes: _notesController.text.trim(),
        isCompleted: editing?.isCompleted ?? false,
      );

      if (editing != null) {
        CalendarEventRepository().updateEvent(newEvent);
        Navigator.pop(context);
        showActionSuccessModal(
          context: context,
          title: 'Event Updated Successfully',
          message: 'Appointment "${newEvent.title}" has been updated.',
          icon: Icons.event_available_rounded,
        );
        return;
      }

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
      showActionSuccessModal(
        context: context,
        title: 'Appointment Scheduled Successfully',
        message: 'Event "${newEvent.title}" has been added to your calendar and scheduled.',
        icon: Icons.event_available_rounded,
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
            ? BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                    margin: EdgeInsets.only(bottom: 16),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.event != null ? 'Edit Clinical Event' : 'Add Clinical Event',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.event != null
                                    ? 'Modify appointment or procedure'
                                    : 'Schedule appointment or procedure',
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
                    icon: Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Event Title Field
              FieldLabel('Event Title', required: true),
              SizedBox(height: 6),
              RequiredTextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Glaucoma Consultation & IOP Check',
                ),
              ),
              SizedBox(height: 16),

              // Patient: a dropdown with a search box (there can be hundreds of patients)
              ClinicalDropdownField<Patient>(
                label: FieldLabel('Patient Name'),
                placeholder: 'Select patient...',
                value: _selectedPatient,
                displayText: _selectedPatient != null ? '${_selectedPatient!.fullName} (${_selectedPatient!.mrn})' : null,
                searchable: true,
                searchHint: 'Search patient by name...',
                items: [
                  for (final p in allPatients)
                    ClinicalPickerItem<Patient>(
                      value: p,
                      label: p.fullName,
                      subtitle: '${p.mrn} • ${p.gender}, ${p.age} yrs',
                    ),
                ],
                onChanged: (patient) => setState(() => _selectedPatient = patient),
              ),
              SizedBox(height: 16),

              // Event Type & Location (Row on wider screens, stacked on narrow mobile)
              ListenableBuilder(
                listenable: _options,
                builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;
                  // The clinic's own lists can be added to and deleted from right in the dropdown.
                  final typeField = ClinicalDropdownField<String>(
                    label: FieldLabel('Event Type'),
                    placeholder: 'None',
                    value: _selectedEventType,
                    items: _choices(_options.types, _selectedEventType),
                    onChanged: (v) => setState(() => _selectedEventType = v.isEmpty ? null : v),
                    itemNoun: 'event type',
                    maxNameLength: EventOptionsStore.maxNameLength,
                    onAdd: _options.addType,
                    onRemove: (v) {
                      _options.removeType(v);
                      if (_selectedEventType == v) setState(() => _selectedEventType = null);
                    },
                  );

                  final locationField = ClinicalDropdownField<String>(
                    label: FieldLabel('Location'),
                    placeholder: 'None',
                    value: _selectedLocation,
                    items: _choices(_options.locations, _selectedLocation),
                    onChanged: (v) => setState(() => _selectedLocation = v.isEmpty ? null : v),
                    itemNoun: 'location',
                    maxNameLength: EventOptionsStore.maxNameLength,
                    onAdd: _options.addLocation,
                    onRemove: (v) {
                      _options.removeLocation(v);
                      if (_selectedLocation == v) setState(() => _selectedLocation = null);
                    },
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        typeField,
                        SizedBox(height: 16),
                        locationField,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: typeField),
                      SizedBox(width: 12),
                      Expanded(child: locationField),
                    ],
                  );
                },
                ),
              ),
              SizedBox(height: 16),

              // Date & Time Touch Pickers
              FieldLabel('Schedule Date & Time', required: true),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryBlue),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                style: TextStyle(
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
                  SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 18, color: AppTheme.primaryBlue),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedTime.format(context),
                                style: TextStyle(
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
              SizedBox(height: 16),


              // Notes Input
              Text(
                'Clinical Notes / Reason for Visit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add clinical instructions or special equipment requests...',
                ),
              ),
              SizedBox(height: 24),

              // Save Action Button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saveEvent,
                  icon: Icon(Icons.check_rounded, size: 22),
                  label: Text(
                    widget.event != null ? 'Save Changes' : 'Confirm & Save Event',
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
