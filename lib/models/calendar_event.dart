import 'dart:async';
import 'package:flutter/material.dart';

import '../services/firebase_gate.dart';
import '../services/offline_sync_service.dart';

class CalendarEvent {
  final String id;
  final String teamId;
  final String title;
  final String eventType; // Surgery, Checkup, Follow-up, IOP Check, Emergency, Laser Procedure
  final String location;  // Davao, Bukidnon, General Santos, Exam Room 1, Exam Room 2, OR Suite 3
  final DateTime dateTime;
  final String patientName;
  final String? patientId;
  final String notes;
  final int reminderMinutes; // Minutes before event to trigger notification (e.g., 15, 30, 60, 1440)
  bool isCompleted;
  bool notificationTriggered;

  CalendarEvent({
    required this.id,
    this.teamId = '',
    required this.title,
    required this.eventType,
    required this.location,
    required this.dateTime,
    required this.patientName,
    this.patientId,
    this.notes = '',
    this.reminderMinutes = 30,
    this.isCompleted = false,
    this.notificationTriggered = false,
  });

  CalendarEvent copyWith({
    String? id,
    String? teamId,
    String? title,
    String? eventType,
    String? location,
    DateTime? dateTime,
    String? patientName,
    String? patientId,
    String? notes,
    int? reminderMinutes,
    bool? isCompleted,
    bool? notificationTriggered,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      title: title ?? this.title,
      eventType: eventType ?? this.eventType,
      location: location ?? this.location,
      dateTime: dateTime ?? this.dateTime,
      patientName: patientName ?? this.patientName,
      patientId: patientId ?? this.patientId,
      notes: notes ?? this.notes,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      notificationTriggered: notificationTriggered ?? this.notificationTriggered,
    );
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    final rawDate = json['dateTime'] ?? json['date_time'] ?? json['timestamp'] ?? json['date'];
    if (rawDate != null) {
      if (rawDate is String) {
        parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
      } else if (rawDate is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
      } else {
        // Dynamic check for Firestore Timestamp object
        try {
          final dynamic t = rawDate;
          if (t.toDate != null) {
            parsedDate = t.toDate() as DateTime;
          }
        } catch (_) {}
      }
    }

    return CalendarEvent(
      id: json['id'] as String? ?? '',
      teamId: json['teamId'] as String? ?? json['team_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      eventType: json['eventType'] as String? ?? json['event_type'] as String? ?? 'Checkup',
      location: json['location'] as String? ?? '',
      dateTime: parsedDate,
      patientName: json['patientName'] as String? ?? json['patient_name'] as String? ?? '',
      patientId: json['patientId'] as String? ?? json['patient_id'] as String?,
      notes: json['notes'] as String? ?? '',
      reminderMinutes: json['reminderMinutes'] as int? ?? json['reminder_minutes'] as int? ?? 30,
      isCompleted: json['isCompleted'] as bool? ?? json['is_completed'] as bool? ?? false,
      notificationTriggered: json['notificationTriggered'] as bool? ?? json['notification_triggered'] as bool? ?? false,
    );
  }
}

class CalendarEventRepository extends ChangeNotifier {
  static final CalendarEventRepository _instance = CalendarEventRepository._internal();
  factory CalendarEventRepository() => _instance;

  final List<CalendarEvent> _events = [];
  StreamSubscription? _eventsSub;
  String? _activeTeamId;

  CalendarEventRepository._internal() {
    _initSeedData();
  }

  void connect([String? teamId]) {
    _activeTeamId = teamId;
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;
    _eventsSub?.cancel();
    
    // Firestore rules require limit <= 500 for queries on calendarEvents
    _eventsSub = firestore.collection('calendarEvents').limit(500).snapshots().listen((snapshot) {
      _events.clear();
      for (final doc in snapshot.docs) {
        try {
          final data = FirebaseGate.decode(doc.data());
          data['id'] = doc.id;
          final event = CalendarEvent.fromJson(data);
          
          // Team scope filtering: include event if unassigned or matches active team
          if (_activeTeamId == null || _activeTeamId!.isEmpty || event.teamId.isEmpty || event.teamId == _activeTeamId) {
            _events.add(event);
          }
        } catch (e) {
          debugPrint('Error parsing calendar event ${doc.id}: $e');
        }
      }
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Firestore calendar events stream error: $e');
    });
  }

  void disconnect() {
    _eventsSub?.cancel();
    _eventsSub = null;
    _events.clear();
    _activeTeamId = null;
    notifyListeners();
  }

  List<CalendarEvent> get events {
    if (_activeTeamId != null && _activeTeamId!.isNotEmpty) {
      return List.unmodifiable(_events.where((e) => e.teamId.isEmpty || e.teamId == _activeTeamId));
    }
    return List.unmodifiable(_events);
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return _events.where((e) {
      return e.dateTime.year == day.year &&
          e.dateTime.month == day.month &&
          e.dateTime.day == day.day;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<CalendarEvent> getFilteredEvents({
    String? typeFilter,
    String? locationFilter,
    DateTime? specificDay,
    bool? completedFilter,
  }) {
    return _events.where((e) {
      if (typeFilter != null && typeFilter != 'All' && e.eventType != typeFilter) {
        return false;
      }
      if (locationFilter != null && locationFilter != 'All' && e.location != locationFilter) {
        return false;
      }
      if (completedFilter != null && e.isCompleted != completedFilter) {
        return false;
      }
      if (specificDay != null) {
        return e.dateTime.year == specificDay.year &&
            e.dateTime.month == specificDay.month &&
            e.dateTime.day == specificDay.day;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  void addEvent(CalendarEvent event) {
    final eventWithTeam = event.teamId.isEmpty && _activeTeamId != null && _activeTeamId!.isNotEmpty
        ? event.copyWith(teamId: _activeTeamId)
        : event;
    _events.add(eventWithTeam);
    OfflineSyncService().enqueueMutation(
      id: eventWithTeam.id,
      entityType: 'CalendarEvent',
      action: 'CREATE',
      payload: {
        'id': eventWithTeam.id,
        'teamId': eventWithTeam.teamId,
        'title': eventWithTeam.title,
        'eventType': eventWithTeam.eventType,
        'location': eventWithTeam.location,
        'dateTime': eventWithTeam.dateTime.toIso8601String(),
        'patientName': eventWithTeam.patientName,
        'patientId': eventWithTeam.patientId,
        'notes': eventWithTeam.notes,
        'reminderMinutes': eventWithTeam.reminderMinutes,
        'isCompleted': eventWithTeam.isCompleted,
        'lastModified': DateTime.now().toIso8601String(),
      },
    );
    notifyListeners();
  }

  void updateEvent(CalendarEvent updated) {
    final eventWithTeam = updated.teamId.isEmpty && _activeTeamId != null && _activeTeamId!.isNotEmpty
        ? updated.copyWith(teamId: _activeTeamId)
        : updated;
    final idx = _events.indexWhere((e) => e.id == eventWithTeam.id);
    if (idx != -1) {
      _events[idx] = eventWithTeam;
    } else {
      _events.add(eventWithTeam);
    }
    OfflineSyncService().enqueueMutation(
      id: eventWithTeam.id,
      entityType: 'CalendarEvent',
      action: 'UPDATE',
      payload: {
        'id': eventWithTeam.id,
        'teamId': eventWithTeam.teamId,
        'title': eventWithTeam.title,
        'eventType': eventWithTeam.eventType,
        'location': eventWithTeam.location,
        'dateTime': eventWithTeam.dateTime.toIso8601String(),
        'patientName': eventWithTeam.patientName,
        'patientId': eventWithTeam.patientId,
        'notes': eventWithTeam.notes,
        'reminderMinutes': eventWithTeam.reminderMinutes,
        'isCompleted': eventWithTeam.isCompleted,
        'lastModified': DateTime.now().toIso8601String(),
      },
    );
    notifyListeners();
  }

  void toggleEventStatus(String id) {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _events[idx].isCompleted = !_events[idx].isCompleted;
      OfflineSyncService().enqueueMutation(
        id: id,
        entityType: 'CalendarEvent',
        action: 'UPDATE',
        payload: {
          'id': id,
          'teamId': _events[idx].teamId,
          'isCompleted': _events[idx].isCompleted,
          'lastModified': DateTime.now().toIso8601String(),
        },
      );
      notifyListeners();
    }
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    OfflineSyncService().enqueueMutation(
      id: id,
      entityType: 'CalendarEvent',
      action: 'DELETE',
      payload: {'id': id},
    );
    notifyListeners();
  }

  void _initSeedData() {
    final now = DateTime.now();
    _events.addAll([
      CalendarEvent(
        id: 'evt-101',
        title: 'Glaucoma Follow-up & IOP Check',
        eventType: 'IOP Check',
        location: 'Davao',
        dateTime: DateTime(now.year, now.month, now.day, 9, 30),
        patientName: 'Eleanor Vance',
        patientId: 'P-10024',
        reminderMinutes: 15,
        notes: 'Target IOP OD < 15 mmHg. Repeat applanation tonometer.',
      ),
      CalendarEvent(
        id: 'evt-102',
        title: 'Post-Op Cataract Evaluation',
        eventType: 'Follow-up',
        location: 'Bukidnon',
        dateTime: DateTime(now.year, now.month, now.day, 10, 45),
        patientName: 'Carlos Mendoza',
        patientId: 'P-10025',
        reminderMinutes: 30,
        notes: 'Check OD corneal clarity and IOL alignment.',
      ),
      CalendarEvent(
        id: 'evt-103',
        title: 'Phacoemulsification & IOL Surgery',
        eventType: 'Surgery',
        location: 'OR Suite 3',
        dateTime: DateTime(now.year, now.month, now.day, 14, 0),
        patientName: 'Lourdes Sterling',
        patientId: 'P-10026',
        reminderMinutes: 60,
        notes: 'Right eye phacoemulsification with toric IOL placement.',
      ),
      CalendarEvent(
        id: 'evt-104',
        title: 'Diabetic Retinopathy Screening',
        eventType: 'Checkup',
        location: 'Davao',
        dateTime: DateTime(now.year, now.month, now.day + 1, 11, 0),
        patientName: 'Arthur Pendelton',
        patientId: 'P-10027',
        reminderMinutes: 30,
        notes: 'Widefield fundus photos and OCT macula scan.',
      ),
      CalendarEvent(
        id: 'evt-105',
        title: 'Acute Red Eye Evaluation',
        eventType: 'Emergency',
        location: 'Bukidnon',
        dateTime: DateTime(now.year, now.month, now.day + 1, 15, 30),
        patientName: 'Sophia Reyes',
        patientId: 'P-10028',
        reminderMinutes: 15,
        notes: 'Rule out corneal ulcer vs anterior uveitis.',
      ),
      CalendarEvent(
        id: 'evt-106',
        title: 'YAG Laser Capsulotomy',
        eventType: 'Laser Procedure',
        location: 'General Santos',
        dateTime: DateTime(now.year, now.month, now.day + 2, 10, 0),
        patientName: 'Gabriel Santos',
        patientId: 'P-10029',
        reminderMinutes: 30,
        notes: 'Post-cataract posterior capsule opacification.',
      ),
    ]);
  }
}
