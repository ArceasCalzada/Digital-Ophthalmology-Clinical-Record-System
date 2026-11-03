import 'package:flutter/material.dart';
import 'patient.dart';

enum FollowUpStatus {
  overdue,
  dueToday,
  dueSoon,
  upcoming,
}

enum FollowUpSource {
  prescription,
  calendarEvent,
}

class FollowUpReminder {
  final String id;
  final String patientId;
  final String patientName;
  final String patientMrn;
  final String patientPhone;
  final DateTime dueDate;
  final String followUpType; // e.g. 'Prescription Follow-Up', 'Post-Op Review', 'Glaucoma Evaluation', 'Annual Eye Exam'
  final String title;
  final String details;
  final String doctorName;
  final String clinicBranch;
  final bool isScheduled;
  final String? linkedCalendarEventId;
  final String? linkedPrescriptionId;
  final FollowUpSource source;
  final Patient? patient;

  const FollowUpReminder({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientMrn,
    this.patientPhone = '',
    required this.dueDate,
    required this.followUpType,
    required this.title,
    this.details = '',
    this.doctorName = '',
    this.clinicBranch = '',
    this.isScheduled = false,
    this.linkedCalendarEventId,
    this.linkedPrescriptionId,
    this.source = FollowUpSource.prescription,
    this.patient,
  });

  /// Difference in calendar days between `dueDate` (midnight) and reference [now] (midnight).
  int daysUntilDue([DateTime? now]) {
    final ref = now ?? DateTime.now();
    final todayMidnight = DateTime(ref.year, ref.month, ref.day);
    final dueMidnight = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueMidnight.difference(todayMidnight).inDays;
  }

  FollowUpStatus getStatus([DateTime? now]) {
    final diff = daysUntilDue(now);
    if (diff < 0) return FollowUpStatus.overdue;
    if (diff == 0) return FollowUpStatus.dueToday;
    if (diff <= 3) return FollowUpStatus.dueSoon;
    return FollowUpStatus.upcoming;
  }

  String getStatusLabel([DateTime? now]) {
    final diff = daysUntilDue(now);
    if (diff < 0) {
      final daysAgo = -diff;
      return daysAgo == 1 ? 'Overdue by 1 day' : 'Overdue by $daysAgo days';
    }
    if (diff == 0) return 'Due Today';
    if (diff == 1) return 'Due Tomorrow';
    if (diff <= 3) return 'Due in $diff days';
    return 'Due in $diff days';
  }

  Color getStatusColor([DateTime? now]) {
    switch (getStatus(now)) {
      case FollowUpStatus.overdue:
        return const Color(0xFFDC2626); // Crimson / Red
      case FollowUpStatus.dueToday:
        return const Color(0xFFD97706); // Amber / Deep Orange
      case FollowUpStatus.dueSoon:
        return const Color(0xFF2563EB); // Royal Blue
      case FollowUpStatus.upcoming:
        return const Color(0xFF64748B); // Slate Gray
    }
  }

  Color getStatusBgColor([DateTime? now]) {
    switch (getStatus(now)) {
      case FollowUpStatus.overdue:
        return const Color(0xFFFEE2E2); // Light red
      case FollowUpStatus.dueToday:
        return const Color(0xFFFEF3C7); // Light amber
      case FollowUpStatus.dueSoon:
        return const Color(0xFFDBEAFE); // Light blue
      case FollowUpStatus.upcoming:
        return const Color(0xFFF1F5F9); // Light slate
    }
  }

  IconData getStatusIcon([DateTime? now]) {
    switch (getStatus(now)) {
      case FollowUpStatus.overdue:
        return Icons.warning_amber_rounded;
      case FollowUpStatus.dueToday:
        return Icons.notifications_active_rounded;
      case FollowUpStatus.dueSoon:
        return Icons.alarm_rounded;
      case FollowUpStatus.upcoming:
        return Icons.event_available_rounded;
    }
  }

  FollowUpReminder copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? patientMrn,
    String? patientPhone,
    DateTime? dueDate,
    String? followUpType,
    String? title,
    String? details,
    String? doctorName,
    String? clinicBranch,
    bool? isScheduled,
    String? linkedCalendarEventId,
    String? linkedPrescriptionId,
    FollowUpSource? source,
    Patient? patient,
  }) {
    return FollowUpReminder(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      patientMrn: patientMrn ?? this.patientMrn,
      patientPhone: patientPhone ?? this.patientPhone,
      dueDate: dueDate ?? this.dueDate,
      followUpType: followUpType ?? this.followUpType,
      title: title ?? this.title,
      details: details ?? this.details,
      doctorName: doctorName ?? this.doctorName,
      clinicBranch: clinicBranch ?? this.clinicBranch,
      isScheduled: isScheduled ?? this.isScheduled,
      linkedCalendarEventId: linkedCalendarEventId ?? this.linkedCalendarEventId,
      linkedPrescriptionId: linkedPrescriptionId ?? this.linkedPrescriptionId,
      source: source ?? this.source,
      patient: patient ?? this.patient,
    );
  }
}

