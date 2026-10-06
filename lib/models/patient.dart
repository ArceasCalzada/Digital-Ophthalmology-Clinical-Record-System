import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show QuerySnapshot, Query;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_limits.dart';
import '../services/firebase_gate.dart';
import '../services/offline_sync_service.dart';
import '../services/storage_optimization_service.dart';
import 'encounter.dart';
import 'prescription.dart';

String formatClinicalDate(String dateStr) {
  if (dateStr.isEmpty) return dateStr;
  try {
    // If format like "7/30/26" or "07/30/2026"
    if (dateStr.contains('/')) {
      final slashParts = dateStr.split('/');
      if (slashParts.length == 3) {
        final m = int.tryParse(slashParts[0]) ?? 1;
        final d = int.tryParse(slashParts[1]) ?? 1;
        var y = slashParts[2];
        if (y.length == 2) y = '20$y';
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final monthName = (m >= 1 && m <= 12) ? months[m - 1] : slashParts[0];
        return '$monthName $d, $y';
      }
    }
    // If format like "2026-07-30" or ISO format
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      final year = parts[0];
      final monthIndex = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthName = (monthIndex >= 1 && monthIndex <= 12) ? months[monthIndex - 1] : parts[1];
      return '$monthName $day, $year';
    }
    final dt = DateTime.tryParse(dateStr);
    if (dt != null) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }
  } catch (_) {}
  return dateStr;
}

/// Formats an ISO registration timestamp into e.g. "September 29, 2026, 9:42 AM".
String formatRegistrationDate(String isoStr) {
  if (isoStr.isEmpty) return 'N/A';
  try {
    final dt = DateTime.tryParse(isoStr)?.toLocal();
    if (dt != null) {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final monthName = months[dt.month - 1];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$monthName ${dt.day}, ${dt.year}, $hour:$minute $period';
    }
  } catch (_) {}
  return isoStr;
}

/// Parses the date-of-birth formats the app stores: "1985-06-15", "Jun 15, 1985" and
/// "6/15/1985" (month first). Returns null for anything else or for an impossible
/// date such as Feb 30.
DateTime? parseDateOfBirth(String text, {DateTime? now}) {
  final value = text.trim();
  if (value.isEmpty) return null;
  const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

  int? year, month, day;
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
  final named = RegExp(r'^([A-Za-z]{3,9})\.?\s+(\d{1,2}),?\s+(\d{4})$').firstMatch(value);
  final slashed = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})$').firstMatch(value);
  if (iso != null) {
    year = int.parse(iso.group(1)!);
    month = int.parse(iso.group(2)!);
    day = int.parse(iso.group(3)!);
  } else if (named != null) {
    final index = months.indexOf(named.group(1)!.substring(0, 3).toLowerCase());
    if (index == -1) return null;
    month = index + 1;
    day = int.parse(named.group(2)!);
    year = int.parse(named.group(3)!);
  } else if (slashed != null) {
    month = int.parse(slashed.group(1)!);
    day = int.parse(slashed.group(2)!);
    year = int.parse(slashed.group(3)!);
    if (year < 100) {
      // Two-digit years: the latest century that is not in the future.
      final currentYear = (now ?? DateTime.now()).year;
      year += (2000 + year > currentYear) ? 1900 : 2000;
    }
  } else {
    return null;
  }

  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day ? date : null;
}

/// The age at [now] for a date of birth, in the largest fitting unit: "41 years",
/// "1 year", "8 months" or "12 days". Null when the date is unreadable or in the future.
String? formatAge(String dateOfBirth, {DateTime? now}) {
  final dob = parseDateOfBirth(dateOfBirth, now: now);
  if (dob == null) return null;
  final today = now ?? DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  if (dob.isAfter(todayDate)) return null;

  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';
  var months = (todayDate.year - dob.year) * 12 + todayDate.month - dob.month;
  if (todayDate.day < dob.day) months--;
  if (months >= 12) return plural(months ~/ 12, 'year');
  if (months >= 1) return plural(months, 'month');
  return plural(todayDate.difference(dob).inDays, 'day');
}

class TodayPatientQueue {
  final Patient patient;
  final String time;
  final String visitType;
  final String status; // 'Waiting', 'In Examination', 'Completed'

  TodayPatientQueue({
    required this.patient,
    required this.time,
    required this.visitType,
    required this.status,
  });
}

class Patient {
  final String id;
  final String mrn; // Medical Record Number
  final String firstName;
  final String middleName;
  final String lastName;
  final String fullName;
  final String dateOfBirth; // YYYY-MM-DD or formatted string
  final String gender;
  final String phone;
  final String address;
  final String occupation;
  final String phicNumber;
  final String? referringDoctor;

  /// General free-text notes about the patient (not tied to a visit).
  final String notes;
  final List<String> medicalHistory;
  final List<String> allergies;
  final List<String> previousDiagnoses;
  final List<String> previousPrescriptions;
  final List<Prescription> prescriptions;
  final List<Encounter> encounters;
  final String teamId;
  final String createdAt;
  final String lastVisitDate;
  final int totalVisits;

  Patient({
    required this.id,
    required this.mrn,
    String? firstName,
    String? middleName,
    String? lastName,
    String? fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.phone,
    required this.address,
    this.occupation = '',
    this.phicNumber = '',
    this.referringDoctor,
    this.notes = '',
    required this.medicalHistory,
    required this.allergies,
    this.previousDiagnoses = const [],
    this.previousPrescriptions = const [],
    this.prescriptions = const [],
    required this.encounters,
    this.teamId = '',
    String? createdAt,
    required this.lastVisitDate,
    required this.totalVisits,
  })  : firstName = _resolveFirstName(firstName, fullName),
        middleName = _resolveMiddleName(middleName, fullName),
        lastName = _resolveLastName(lastName, fullName),
        fullName = _resolveFullName(firstName, middleName, lastName, fullName),
        createdAt = (createdAt != null && createdAt.isNotEmpty) ? createdAt : DateTime.now().toIso8601String();

  static String _resolveFirstName(String? firstName, String? fullName) {
    if (firstName != null && firstName.trim().isNotEmpty) {
      return firstName.trim();
    }
    if (fullName != null && fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(RegExp(r'\s+'));
      return parts.first;
    }
    return '';
  }

  static String _resolveMiddleName(String? middleName, String? fullName) {
    if (middleName != null && middleName.trim().isNotEmpty) {
      return middleName.trim();
    }
    if (fullName != null && fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        return parts.sublist(1, parts.length - 1).join(' ');
      }
    }
    return '';
  }

  static String _resolveLastName(String? lastName, String? fullName) {
    if (lastName != null && lastName.trim().isNotEmpty) {
      return lastName.trim();
    }
    if (fullName != null && fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(RegExp(r'\s+'));
      if (parts.length > 1) {
        return parts.last;
      }
    }
    return '';
  }

  static String _resolveFullName(String? firstName, String? middleName, String? lastName, String? fullName) {
    final f = _resolveFirstName(firstName, fullName);
    final m = _resolveMiddleName(middleName, fullName);
    final l = _resolveLastName(lastName, fullName);

    if (f.isNotEmpty || l.isNotEmpty) {
      final parts = [f, m, l].where((s) => s.isNotEmpty).toList();
      return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    return '';
  }

  int get age {
    // "Jun 15, 1985" (what the registration form stores) is not an ISO date, so it used
    // to fall through to the year-only guess below and ignore the birthday.
    final dob = parseDateOfBirth(dateOfBirth) ?? DateTime.tryParse(dateOfBirth);
    if (dob == null) {
      final parts = dateOfBirth.split(RegExp(r'[,/\s]+'));
      if (parts.length >= 3) {
        final y = int.tryParse(parts.last);
        if (y != null) {
          return DateTime.now().year - y;
        }
      }
      return 45;
    }
    final now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mrn': mrn,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'fullName': fullName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'phone': phone,
        'address': address,
        'occupation': occupation,
        'phicNumber': phicNumber,
        'referringDoctor': referringDoctor,
        'notes': notes,
        'medicalHistory': medicalHistory,
        'allergies': allergies,
        'previousDiagnoses': previousDiagnoses,
        'previousPrescriptions': previousPrescriptions,
        'prescriptions': prescriptions.map((p) => p.toJson()).toList(),
        'encounters': encounters.map((e) => e.toJson()).toList(),
        if (teamId.isNotEmpty) 'teamId': teamId,
        'createdAt': createdAt,
        'lastVisitDate': lastVisitDate,
        'totalVisits': totalVisits,
      };

  /// Document stored at `patients/{id}`: demographics and a small visit summary
  /// only. Encounters and prescriptions live in subcollections so this document
  /// stays small no matter how many visits a patient has.
  ///
  /// Throws [FormatException] when a field is over its limit.
  Map<String, dynamic> toFirestore() {
    void requireLength(String label, String value, int max) {
      if (value.length > max) {
        throw FormatException('$label is too long (${value.length} characters, limit $max).');
      }
    }

    List<String> requireList(String label, List<String> items, [int maxItems = AppLimits.maxListItems]) {
      if (items.length > maxItems) {
        throw FormatException('$label has too many entries (${items.length}, limit $maxItems).');
      }
      for (final item in items) {
        requireLength(label, item, AppLimits.maxShortTextLength);
      }
      return items;
    }

    requireLength('First name', firstName, AppLimits.maxShortTextLength);
    requireLength('Middle name', middleName, AppLimits.maxShortTextLength);
    requireLength('Last name', lastName, AppLimits.maxShortTextLength);
    requireLength('Full name', fullName, AppLimits.maxShortTextLength);
    requireLength('MRN', mrn, AppLimits.maxShortTextLength);
    requireLength('Date of birth', dateOfBirth, AppLimits.maxShortTextLength);
    requireLength('Gender', gender, AppLimits.maxShortTextLength);
    requireLength('Phone', phone, AppLimits.maxShortTextLength);
    requireLength('Address', address, AppLimits.maxShortTextLength);
    requireLength('Occupation', occupation, AppLimits.maxShortTextLength);
    requireLength('PHIC number', phicNumber, AppLimits.maxShortTextLength);
    if (referringDoctor != null) requireLength('Referring doctor', referringDoctor!, AppLimits.maxShortTextLength);
    requireLength('Notes', notes, AppLimits.maxNotesLength);

    return {
      'id': id,
      'mrn': mrn,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'fullName': fullName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'phone': phone,
      'address': address,
      'occupation': occupation,
      'phicNumber': phicNumber,
      'referringDoctor': referringDoctor,
      // Only sent when there is something to say, so a patient without notes is written
      // exactly as before (rules published before this field existed still accept it).
      if (notes.isNotEmpty) 'notes': notes,
      if (teamId.isNotEmpty) 'teamId': teamId,
      'createdAt': createdAt,
      'medicalHistory': requireList('Medical history', medicalHistory),
      'allergies': requireList('Allergies', allergies),
      'previousDiagnoses': requireList(
        'Previous diagnoses',
        previousDiagnoses.take(AppLimits.maxDiagnosisSummary).toList(),
        AppLimits.maxSummaryListItems,
      ),
      'previousPrescriptions': requireList('Previous prescriptions', previousPrescriptions, AppLimits.maxSummaryListItems),
      'lastVisitDate': lastVisitDate,
      'totalVisits': totalVisits,
      'lastModified': DateTime.now().toIso8601String(),
    };
  }

  Patient copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? fullName,
    String? occupation,
    String? phicNumber,
    List<String>? previousDiagnoses,
    List<Prescription>? prescriptions,
    List<Encounter>? encounters,
    String? teamId,
    String? createdAt,
    String? lastVisitDate,
    int? totalVisits,
  }) =>
      Patient(
        id: id,
        mrn: mrn,
        firstName: firstName ?? this.firstName,
        middleName: middleName ?? this.middleName,
        lastName: lastName ?? this.lastName,
        fullName: fullName ?? (firstName != null || middleName != null || lastName != null ? null : this.fullName),
        dateOfBirth: dateOfBirth,
        gender: gender,
        phone: phone,
        address: address,
        occupation: occupation ?? this.occupation,
        phicNumber: phicNumber ?? this.phicNumber,
        referringDoctor: referringDoctor,
        notes: notes,
        medicalHistory: medicalHistory,
        allergies: allergies,
        previousDiagnoses: previousDiagnoses ?? this.previousDiagnoses,
        previousPrescriptions: previousPrescriptions,
        prescriptions: prescriptions ?? this.prescriptions,
        encounters: encounters ?? this.encounters,
        teamId: teamId ?? this.teamId,
        createdAt: createdAt ?? this.createdAt,
        lastVisitDate: lastVisitDate ?? this.lastVisitDate,
        totalVisits: totalVisits ?? this.totalVisits,
      );

  factory Patient.fromJson(Map<String, dynamic> json) {
    String extractString(List<String> keys, String defaultValue) {
      for (final key in keys) {
        if (json[key] != null && json[key].toString().trim().isNotEmpty) {
          return json[key].toString().trim();
        }
      }
      return defaultValue;
    }

    List<String> extractStringList(List<String> keys) {
      for (final key in keys) {
        final val = json[key];
        if (val is List) {
          return val.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        } else if (val is String && val.trim().isNotEmpty) {
          return [val.trim()];
        }
      }
      return [];
    }

    final id = extractString(['id', 'patientId', 'docId'], 'pat-${DateTime.now().millisecondsSinceEpoch}');
    final mrn = extractString(['mrn', 'MRN', 'medicalRecordNumber'], 'PT-000000');

    final rawFirst = extractString(['firstName', 'first_name'], '');
    final rawMiddle = extractString(['middleName', 'middle_name'], '');
    final rawLast = extractString(['lastName', 'last_name'], '');
    String rawFull = extractString(['fullName', 'name', 'full_name', 'patientName'], '');

    String firstName = rawFirst;
    String middleName = rawMiddle;
    String lastName = rawLast;
    String fullName = rawFull;

    if (firstName.isEmpty || lastName.isEmpty) {
      if (fullName.isNotEmpty) {
        final parts = fullName.trim().split(RegExp(r'\s+'));
        if (parts.length == 1) {
          if (firstName.isEmpty) firstName = parts[0];
        } else if (parts.length == 2) {
          if (firstName.isEmpty) firstName = parts[0];
          if (lastName.isEmpty) lastName = parts[1];
        } else if (parts.length >= 3) {
          if (firstName.isEmpty) firstName = parts[0];
          if (lastName.isEmpty) lastName = parts.last;
          if (middleName.isEmpty) middleName = parts.sublist(1, parts.length - 1).join(' ');
        }
      }
    }

    if (fullName.isEmpty) {
      final parts = [firstName, middleName, lastName].where((s) => s.isNotEmpty).toList();
      fullName = parts.join(' ');
    }

    if (fullName.isEmpty) {
      fullName = 'Patient $mrn';
    }

    final dateOfBirth = extractString(['dateOfBirth', 'dob', 'date_of_birth', 'birthDate'], '1985-06-15');
    final gender = extractString(['gender', 'sex'], 'Unspecified');
    final phone = extractString(['phone', 'contactNumber', 'phoneNumber', 'mobile', 'contact'], 'N/A');
    final address = extractString(['address', 'location'], 'N/A');
    final occupation = extractString(['occupation', 'job'], '');
    final phicNumber = extractString(['phicNumber', 'phic', 'phic_number', 'phicNo', 'phic_no'], '');
    final referringDoctor = json['referringDoctor']?.toString() ?? json['doctor']?.toString();
    final notes = extractString(['notes'], '');
    final teamId = extractString(['teamId', 'team_id'], '');
    final createdAt = extractString(['createdAt', 'created_at', 'registeredAt', 'registrationDate'], '');

    final medicalHistory = extractStringList(['medicalHistory', 'medical_history']);
    final allergies = extractStringList(['allergies']);
    final previousDiagnoses = extractStringList(['previousDiagnoses', 'diagnoses']);
    final previousPrescriptions = extractStringList(['previousPrescriptions']);

    final rxList = <Prescription>[];
    if (json['prescriptions'] is List) {
      for (final item in json['prescriptions'] as List) {
        if (item is Map) {
          try {
            rxList.add(Prescription.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
    }

    final encList = <Encounter>[];
    if (json['encounters'] is List) {
      for (final item in json['encounters'] as List) {
        if (item is Map) {
          try {
            encList.add(Encounter.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
    }

    final lastVisitDate = extractString(['lastVisitDate', 'last_visit', 'lastVisit'], DateTime.now().toString().substring(0, 10));
    final totalVisits = (json['totalVisits'] as num?)?.toInt() ?? (json['visits'] as num?)?.toInt() ?? 1;

    return Patient(
      id: id,
      mrn: mrn,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      phone: phone,
      address: address,
      occupation: occupation,
      phicNumber: phicNumber,
      referringDoctor: referringDoctor,
      notes: notes,
      medicalHistory: medicalHistory,
      allergies: allergies,
      previousDiagnoses: previousDiagnoses,
      previousPrescriptions: previousPrescriptions,
      prescriptions: rxList,
      encounters: encList,
      teamId: teamId,
      createdAt: createdAt.isNotEmpty ? createdAt : null,
      lastVisitDate: lastVisitDate,
      totalVisits: totalVisits,
    );
  }
}

/// Thrown when adding a patient would exceed [AppLimits.maxPatients].
class PatientLimitReachedException implements Exception {
  final int limit;
  const PatientLimitReachedException(this.limit);

  @override
  String toString() =>
      'The clinic has reached its limit of $limit stored patient records. Ask an administrator to archive old records before adding new patients.';
}

/// In-memory view of the clinic's patients, backed by Cloud Firestore.
///
class PaginatedResult<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  PaginatedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });
}

/// In-memory view of the clinic's patients, backed by Cloud Firestore.
///
/// * `patients/{id}` holds demographics only and is streamed for the directory
///   (at most [AppLimits.maxPatients] documents).
/// * Encounters and prescriptions are loaded per patient on demand with
///   [loadPatientDetails] from `patients/{id}/encounters` and `.../prescriptions`.
/// * Nothing is written to on-device key/value storage; offline persistence is
///   handled (and bounded) by Firestore itself.
/// * Without Firebase (unit tests) it works purely in memory.
class PatientRepository {
  static const int maxPatients = AppLimits.maxPatients;
  static const int maxEncountersPerPatient = AppLimits.maxEncountersPerPatient;

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  static final List<Patient> _patients = [];

  /// Patients created on this device that the cloud snapshot has not shown yet.
  static final Map<String, Patient> _pendingPatients = {};

  static StreamSubscription? _patientsSub;
  static StreamSubscription? _encountersSub;
  static StreamSubscription? _prescriptionsSub;
  static String? _detailPatientId;

  /// Removes patient data that older versions stored unencrypted in local
  /// key/value storage (`localStorage` on web).
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['docrs_patients_v1', 'docrs_user_logged_in', 'docrs_user_email']) {
        if (prefs.containsKey(key)) await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('PatientRepository legacy cleanup skipped: $e');
    }
  }

  static String? _activeTeamId;

  /// Starts streaming the patient directory for the active team.
  static void connect([String? teamId]) {
    final targetTeamId = teamId ?? _activeTeamId;
    final teamChanged = _activeTeamId != targetTeamId;
    _activeTeamId = targetTeamId;

    final firestore = FirebaseGate.firestoreIfReady();

    if (teamChanged) {
      _cancelDetails();
      if (firestore != null) {
        _patients.clear();
        _pendingPatients.clear();
      } else if (targetTeamId != null && targetTeamId.isNotEmpty) {
        for (var i = 0; i < _patients.length; i++) {
          if (_patients[i].teamId.isEmpty) {
            _patients[i] = _patients[i].copyWith(teamId: targetTeamId);
          }
        }
      }
      changeNotifier.value++;
    }

    if (firestore == null) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    _patientsSub?.cancel();

    Query<Map<String, dynamic>> query = firestore.collection('patients');
    if (targetTeamId != null && targetTeamId.isNotEmpty) {
      query = query.where('teamId', isEqualTo: targetTeamId);
    }
    query = query.limit(AppLimits.patientListLimit);

    _patientsSub = query.snapshots().listen(_onPatientsSnapshot, onError: (Object e) {
      debugPrint('Firestore patients stream error: $e');
      isLoading.value = false;
    });

    if (targetTeamId != null && targetTeamId.isNotEmpty) {
      migrateUnassignedPatientsToTeam(targetTeamId);
    }
  }

  /// Migrates legacy unassigned patient records into the given team ID.
  static Future<void> migrateUnassignedPatientsToTeam(String teamId) async {
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null || teamId.isEmpty) return;

    try {
      final unassigned = await firestore
          .collection('patients')
          .where('teamId', isEqualTo: '')
          .get();
      if (unassigned.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in unassigned.docs) {
          batch.update(doc.reference, {'teamId': teamId});
        }
        await batch.commit();
        debugPrint('Migrated ${unassigned.docs.length} unassigned patient records to team $teamId');
      }
    } catch (e) {
      debugPrint('Patient data migration check: $e');
    }
  }

  /// Stops all listeners and drops patient data from memory (sign-out).
  static void disconnect() {
    _patientsSub?.cancel();
    _patientsSub = null;
    _cancelDetails();
    _patients.clear();
    _pendingPatients.clear();
    isLoading.value = false;
    changeNotifier.value++;
  }

  static void _cancelDetails() {
    _encountersSub?.cancel();
    _prescriptionsSub?.cancel();
    _encountersSub = null;
    _prescriptionsSub = null;
    _detailPatientId = null;
  }

  static void _onPatientsSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final previousById = {for (final p in _patients) p.id: p};
    final fromCloud = <Patient>[];
    for (final doc in snapshot.docs) {
      try {
        final data = FirebaseGate.decode(doc.data());
        data['id'] = doc.id;
        var patient = Patient.fromJson(data);
        final known = previousById[patient.id];
        if (known != null) {
          // Keep already-loaded visits and prescriptions; the directory document has none.
          patient = patient.copyWith(encounters: known.encounters, prescriptions: known.prescriptions);
        }
        _pendingPatients.remove(patient.id);
        fromCloud.add(patient);
      } catch (e) {
        debugPrint('Error parsing Firestore patient ${doc.id}: $e');
      }
    }
    _patients
      ..clear()
      ..addAll(_pendingPatients.values)
      ..addAll(fromCloud);
    isLoading.value = false;
    changeNotifier.value++;
  }

  /// Loads (and keeps live) the visits and prescriptions of one patient.
  /// Only one patient's details are streamed at a time.
  static void loadPatientDetails(String patientId) {
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null || _detailPatientId == patientId) return;
    _cancelDetails();
    _detailPatientId = patientId;
    final base = firestore.collection('patients').doc(patientId);

    _encountersSub = base
        .collection('encounters')
        .orderBy('lastModified', descending: true)
        .limit(AppLimits.subcollectionListLimit)
        .snapshots()
        .listen((snapshot) {
      final encounters = <Encounter>[];
      for (final doc in snapshot.docs) {
        try {
          final data = FirebaseGate.decode(doc.data());
          data['id'] = doc.id;
          data['patientId'] = patientId;
          encounters.add(Encounter.fromFirestore(data));
        } catch (e) {
          debugPrint('Error parsing encounter ${doc.id}: $e');
        }
      }
      _replaceDetails(patientId, encounters: encounters);
    }, onError: (Object e) => debugPrint('Encounters stream error: $e'));

    _prescriptionsSub = base
        .collection('prescriptions')
        .orderBy('lastModified', descending: true)
        .limit(AppLimits.subcollectionListLimit)
        .snapshots()
        .listen((snapshot) {
      final prescriptions = <Prescription>[];
      for (final doc in snapshot.docs) {
        try {
          final data = FirebaseGate.decode(doc.data());
          data['id'] = doc.id;
          data['patientId'] = patientId;
          prescriptions.add(Prescription.fromJson(data));
        } catch (e) {
          debugPrint('Error parsing prescription ${doc.id}: $e');
        }
      }
      _replaceDetails(patientId, prescriptions: prescriptions);
    }, onError: (Object e) => debugPrint('Prescriptions stream error: $e'));
  }

  static void _replaceDetails(String patientId, {List<Encounter>? encounters, List<Prescription>? prescriptions}) {
    final idx = _patients.indexWhere((p) => p.id == patientId);
    if (idx == -1) return;
    _patients[idx] = _patients[idx].copyWith(encounters: encounters, prescriptions: prescriptions);
    changeNotifier.value++;
  }

  static List<Patient> getAllPatients() {
    if (_activeTeamId != null && _activeTeamId!.isNotEmpty) {
      return List.unmodifiable(_patients.where((p) => p.teamId.isEmpty || p.teamId == _activeTeamId));
    }
    return List.unmodifiable(_patients);
  }

  static Patient? getPatientById(String id) {
    try {
      return _patients.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<Patient> searchPatients(String query) {
    final base = getAllPatients();
    if (query.trim().isEmpty) return base;
    final q = query.trim().toLowerCase();
    final cleanDigitsQuery = q.replaceAll(RegExp(r'\D'), '');

    return base.where((p) {
      final nameMatch = p.fullName.toLowerCase().contains(q) ||
          p.middleName.toLowerCase().contains(q);
      final mrnMatch = p.mrn.toLowerCase().contains(q);
      final idMatch = p.id.toLowerCase().contains(q);

      final phoneClean = p.phone.replaceAll(RegExp(r'\D'), '');
      final phoneMatch = p.phone.toLowerCase().contains(q) ||
          (cleanDigitsQuery.isNotEmpty && phoneClean.contains(cleanDigitsQuery));

      final addressMatch = p.address.toLowerCase().contains(q);

      return nameMatch || mrnMatch || idMatch || phoneMatch || addressMatch;
    }).toList();
  }

  /// Fetches a paginated slice of patients based on page number, page size, search query, and filter.
  static PaginatedResult<Patient> getPaginatedPatients({
    int page = 1,
    int pageSize = 20,
    String searchQuery = '',
    String filter = 'All',
  }) {
    List<Patient> base = getAllPatients();
    if (filter != 'All') {
      base = searchPatients(filter);
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      final cleanDigitsQuery = q.replaceAll(RegExp(r'\D'), '');
      base = base.where((p) {
        final nameMatch = p.fullName.toLowerCase().contains(q) ||
            p.middleName.toLowerCase().contains(q);
        final mrnMatch = p.mrn.toLowerCase().contains(q);
        final idMatch = p.id.toLowerCase().contains(q);
        final phoneClean = p.phone.replaceAll(RegExp(r'\D'), '');
        final phoneMatch = p.phone.toLowerCase().contains(q) ||
            (cleanDigitsQuery.isNotEmpty && phoneClean.contains(cleanDigitsQuery));
        final addressMatch = p.address.toLowerCase().contains(q);
        return nameMatch || mrnMatch || idMatch || phoneMatch || addressMatch;
      }).toList();
    }

    final totalCount = base.length;
    final totalPages = (totalCount / pageSize).ceil().clamp(1, 99999);
    final currentPage = page.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, totalCount);

    final items = (startIndex < totalCount) ? base.sublist(startIndex, endIndex) : <Patient>[];

    return PaginatedResult<Patient>(
      items: items,
      totalCount: totalCount,
      page: currentPage,
      pageSize: pageSize,
      totalPages: totalPages,
      hasNext: currentPage < totalPages,
      hasPrevious: currentPage > 1,
    );
  }

  /// Direct Firestore cursor query for batched patient loading using limit & cursor.
  static Future<List<Patient>> fetchPatientsBatch({
    int limit = 20,
    dynamic lastDocumentSnapshot,
    String? teamId,
  }) async {
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) {
      return getAllPatients().take(limit).toList();
    }

    Query<Map<String, dynamic>> query = firestore.collection('patients');
    final targetTeamId = teamId ?? _activeTeamId;
    if (targetTeamId != null && targetTeamId.isNotEmpty) {
      query = query.where('teamId', isEqualTo: targetTeamId);
    }
    query = query.orderBy('createdAt', descending: true).limit(limit);

    if (lastDocumentSnapshot != null) {
      query = query.startAfterDocument(lastDocumentSnapshot);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = FirebaseGate.decode(doc.data());
      data['id'] = doc.id;
      return Patient.fromJson(data);
    }).toList();
  }

  /// Adds a patient (or replaces the one with the same id / MRN).
  ///
  /// Throws [PatientLimitReachedException] when the clinic is full, and
  /// [FormatException] when a field is over its length limit.
  static void addPatient(Patient newPatient) {
    if (newPatient.teamId.isEmpty && _activeTeamId != null && _activeTeamId!.isNotEmpty) {
      newPatient = newPatient.copyWith(teamId: _activeTeamId);
    }
    final existingIdx = _patients.indexWhere((p) => p.id == newPatient.id || p.mrn == newPatient.mrn);
    final isNew = existingIdx == -1;
    if (isNew && _patients.length >= maxPatients) {
      throw const PatientLimitReachedException(maxPatients);
    }

    final data = newPatient.toFirestore();
    StorageOptimizationService.auditAndOptimizePayload(
      data,
      maxDocBytes: AppLimits.maxPatientDocBytes,
      docPath: 'patients/${newPatient.id}',
    );

    if (isNew) {
      _patients.insert(0, newPatient);
      _pendingPatients[newPatient.id] = newPatient;
    } else {
      final old = _patients[existingIdx];
      _patients[existingIdx] = newPatient.encounters.isEmpty && newPatient.prescriptions.isEmpty
          ? newPatient.copyWith(encounters: old.encounters, prescriptions: old.prescriptions)
          : newPatient;
    }
    changeNotifier.value++;

    OfflineSyncService().enqueueMutation(
      id: newPatient.id,
      entityType: 'Patient',
      action: 'CREATE',
      payload: data,
      ops: [
        SyncOp.set('patients/${newPatient.id}', data),
        if (isNew) const SyncOp.increment('meta/counters', {'patientCount': 1}),
      ],
      onRejected: (_) {
        if (isNew) {
          _pendingPatients.remove(newPatient.id);
          _patients.removeWhere((p) => p.id == newPatient.id);
          changeNotifier.value++;
        }
      },
    );
  }

  /// Saves a prescription under its patient.
  ///
  /// Throws [FormatException] when a field is over its length limit.
  static void addPrescription(String patientId, Prescription prescription) {
    final idx = _patients.indexWhere((p) => p.id == patientId);
    if (idx == -1) return;

    if (prescription.items.length > AppLimits.maxPrescriptionItems) {
      throw const FormatException('A prescription can list at most ${AppLimits.maxPrescriptionItems} medications.');
    }
    void requireLength(String label, String value, int max) {
      if (value.length > max) {
        throw FormatException('$label is too long (${value.length} characters, limit $max).');
      }
    }

    requireLength('Prescription notes', prescription.notes, AppLimits.maxNotesLength);
    requireLength('Doctor name', prescription.doctorName, AppLimits.maxShortTextLength);
    for (final item in prescription.items) {
      requireLength('Medication name', item.medicationName, 200);
      requireLength('Strength', item.strength, 200);
      requireLength('Dosage', item.dosage, 200);
      requireLength('Frequency', item.frequency, 200);
      requireLength('Duration', item.duration, 200);
      requireLength('Instructions', item.instructions, AppLimits.maxShortTextLength);
    }

    final data = prescription.toJson()
      ..['patientId'] = patientId
      ..['lastModified'] = DateTime.now().toIso8601String();
    final rxPath = 'patients/$patientId/prescriptions/${prescription.id}';
    StorageOptimizationService.auditAndOptimizePayload(
      data,
      maxDocBytes: AppLimits.maxPrescriptionDocBytes,
      docPath: rxPath,
    );

    final p = _patients[idx];
    _patients[idx] = p.copyWith(prescriptions: [prescription, ...p.prescriptions]);
    changeNotifier.value++;

    OfflineSyncService().enqueueMutation(
      id: prescription.id,
      entityType: 'Prescription',
      action: 'CREATE',
      payload: data,
      ops: [
        SyncOp.set(rxPath, data),
        const SyncOp.increment('meta/counters', {'prescriptionCount': 1}),
      ],
      onRejected: (_) {
        final i = _patients.indexWhere((x) => x.id == patientId);
        if (i == -1) return;
        _patients[i] = _patients[i].copyWith(
          prescriptions: _patients[i].prescriptions.where((r) => r.id != prescription.id).toList(),
        );
        changeNotifier.value++;
      },
    );
  }

  static List<TodayPatientQueue> getTodayQueue() {
    if (_patients.isEmpty) return [];
    final queue = <TodayPatientQueue>[
      TodayPatientQueue(
        patient: _patients.first,
        time: '09:00 AM',
        visitType: 'Clinical Consultation Sheet',
        status: 'In Examination',
      ),
    ];
    if (_patients.length > 1) {
      queue.add(
        TodayPatientQueue(
          patient: _patients[1],
          time: '09:30 AM',
          visitType: 'Follow-up Examination',
          status: 'Waiting',
        ),
      );
    }
    if (_patients.length > 2) {
      queue.add(
        TodayPatientQueue(
          patient: _patients[2],
          time: '10:15 AM',
          visitType: 'Glaucoma Consultation',
          status: 'Waiting',
        ),
      );
    }
    return queue;
  }

  /// Saves a visit (with its drawings) under its patient and updates the
  /// patient's visit summary, in one atomic write.
  ///
  /// Throws [FormatException] for over-long text or too many visits, and
  /// `DrawingTooLargeException` when a drawing cannot be stored.
  static void addEncounter(String patientId, Encounter encounter) {
    final patientIndex = _patients.indexWhere((p) => p.id == patientId);
    if (patientIndex == -1) return;
    final existing = _patients[patientIndex];

    if (existing.encounters.length >= maxEncountersPerPatient) {
      throw const FormatException(
        'This patient has reached the maximum of ${AppLimits.maxEncountersPerPatient} stored visits.',
      );
    }

    final encounterPath = 'patients/$patientId/encounters/${encounter.id}';
    final encounterData = encounter.toFirestore();
    StorageOptimizationService.auditAndOptimizePayload(
      encounterData,
      maxDocBytes: AppLimits.maxEncounterDocBytes,
      docPath: encounterPath,
    );

    final updated = existing.copyWith(
      previousDiagnoses: [encounter.diagnosis, ...existing.previousDiagnoses]
          .take(AppLimits.maxDiagnosisSummary)
          .toList(),
      encounters: [encounter, ...existing.encounters],
      lastVisitDate: encounter.date,
      totalVisits: existing.totalVisits + 1,
    );
    final summary = updated.toFirestore();
    _patients[patientIndex] = updated;
    changeNotifier.value++;

    OfflineSyncService().enqueueMutation(
      id: encounter.id,
      entityType: 'Encounter',
      action: 'CREATE',
      payload: encounterData,
      ops: [
        SyncOp.set(encounterPath, encounterData),
        SyncOp.set('patients/$patientId', {
          'previousDiagnoses': summary['previousDiagnoses'],
          'lastVisitDate': summary['lastVisitDate'],
          'totalVisits': summary['totalVisits'],
          'lastModified': summary['lastModified'],
        }),
        const SyncOp.increment('meta/counters', {'encounterCount': 1}),
      ],
      onRejected: (_) {
        final i = _patients.indexWhere((p) => p.id == patientId);
        if (i == -1) return;
        final current = _patients[i];
        _patients[i] = current.copyWith(
          encounters: current.encounters.where((e) => e.id != encounter.id).toList(),
          totalVisits: current.totalVisits > 0 ? current.totalVisits - 1 : 0,
        );
        changeNotifier.value++;
      },
    );
  }

  @visibleForTesting
  static void clearForTesting() {
    _cancelDetails();
    _patientsSub?.cancel();
    _patientsSub = null;
    _patients.clear();
    _pendingPatients.clear();
    changeNotifier.value++;
  }
}
