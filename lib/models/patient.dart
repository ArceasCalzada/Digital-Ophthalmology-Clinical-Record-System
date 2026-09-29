import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/offline_sync_service.dart';
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
  final String fullName;
  final String middleName;
  final String dateOfBirth; // YYYY-MM-DD or formatted string
  final String gender;
  final String phone;
  final String address;
  final String occupation;
  final String phicNumber;
  final String? referringDoctor;
  final List<String> medicalHistory;
  final List<String> allergies;
  final List<String> previousDiagnoses;
  final List<String> previousPrescriptions;
  final List<Prescription> prescriptions;
  final List<Encounter> encounters;
  final String lastVisitDate;
  final int totalVisits;

  Patient({
    required this.id,
    required this.mrn,
    required this.fullName,
    this.middleName = '',
    required this.dateOfBirth,
    required this.gender,
    required this.phone,
    required this.address,
    this.occupation = 'Civil Servant',
    this.phicNumber = '19-02581024-8',
    this.referringDoctor,
    required this.medicalHistory,
    required this.allergies,
    this.previousDiagnoses = const [],
    this.previousPrescriptions = const [],
    this.prescriptions = const [],
    required this.encounters,
    required this.lastVisitDate,
    required this.totalVisits,
  });

  int get age {
    final dob = DateTime.tryParse(dateOfBirth);
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
        'fullName': fullName,
        'middleName': middleName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'phone': phone,
        'address': address,
        'occupation': occupation,
        'phicNumber': phicNumber,
        'referringDoctor': referringDoctor,
        'medicalHistory': medicalHistory,
        'allergies': allergies,
        'previousDiagnoses': previousDiagnoses,
        'previousPrescriptions': previousPrescriptions,
        'prescriptions': prescriptions.map((p) => p.toJson()).toList(),
        'encounters': encounters.map((e) => e.toJson()).toList(),
        'lastVisitDate': lastVisitDate,
        'totalVisits': totalVisits,
      };

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['id'] as String,
        mrn: json['mrn'] as String,
        fullName: json['fullName'] as String,
        middleName: json['middleName'] as String? ?? '',
        dateOfBirth: json['dateOfBirth'] as String,
        gender: json['gender'] as String,
        phone: json['phone'] as String,
        address: json['address'] as String,
        occupation: json['occupation'] as String? ?? 'Civil Servant',
        phicNumber: json['phicNumber'] as String? ?? '19-02581024-8',
        referringDoctor: json['referringDoctor'] as String?,
        medicalHistory: (json['medicalHistory'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        allergies: (json['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        previousDiagnoses: (json['previousDiagnoses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        previousPrescriptions: (json['previousPrescriptions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        prescriptions: (json['prescriptions'] as List<dynamic>?)?.map((p) => Prescription.fromJson(p as Map<String, dynamic>)).toList() ?? [],
        encounters: (json['encounters'] as List<dynamic>?)?.map((e) => Encounter.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        lastVisitDate: json['lastVisitDate'] as String? ?? DateTime.now().toString().substring(0, 10),
        totalVisits: (json['totalVisits'] as num?)?.toInt() ?? 1,
      );
}

class PatientRepository {
  static const String _storageKey = 'docrs_patients_v1';
  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);
  static final List<Patient> _patients = [];
  static StreamSubscription? _firestoreSubscription;

  static Future<void> init() async {
    // 1. Load locally persisted patients from SharedPreferences first (offline fallback & fast load)
    await _loadFromLocalStorage();

    // 2. Connect to live Cloud Firestore 'patients' collection for real-time sync
    try {
      final options = FirebaseFirestore.instance.app.options;
      if (!options.apiKey.contains('Placeholder')) {
        _firestoreSubscription?.cancel();
        _firestoreSubscription = FirebaseFirestore.instance
            .collection('patients')
            .snapshots()
            .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final List<Patient> firestorePatients = [];
            for (final doc in snapshot.docs) {
              try {
                final data = Map<String, dynamic>.from(doc.data());
                data['id'] = doc.id;
                firestorePatients.add(Patient.fromJson(data));
              } catch (e) {
                debugPrint('Error parsing Firestore patient ${doc.id}: $e');
              }
            }
            if (firestorePatients.isNotEmpty) {
              _patients.clear();
              _patients.addAll(firestorePatients);
              _saveToStorage();
            }
          }
        }, onError: (e) {
          debugPrint('Firestore patients stream error: $e');
        });
      }
    } catch (e) {
      debugPrint('PatientRepository Firestore init error: $e');
    }
  }

  static Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final loaded = jsonList.map((j) => Patient.fromJson(j as Map<String, dynamic>)).toList();
        if (loaded.isNotEmpty) {
          _patients.clear();
          _patients.addAll(loaded);
          changeNotifier.value++;
        }
      }
    } catch (e) {
      debugPrint('PatientRepository local load error: $e');
    }
  }

  static Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _patients.map((p) => p.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
      changeNotifier.value++;
    } catch (e) {
      debugPrint('PatientRepository save error: $e');
    }
  }

  static List<Patient> getAllPatients() => List.unmodifiable(_patients);

  static Patient? getPatientById(String id) {
    try {
      return _patients.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<Patient> searchPatients(String query) {
    if (query.trim().isEmpty) return _patients;
    final q = query.toLowerCase();
    return _patients.where((p) {
      return p.fullName.toLowerCase().contains(q) ||
          p.middleName.toLowerCase().contains(q) ||
          p.mrn.toLowerCase().contains(q) ||
          p.phone.contains(q);
    }).toList();
  }

  static void addPatient(Patient newPatient) {
    _patients.insert(0, newPatient);
    _saveToStorage();
    OfflineSyncService().enqueueMutation(
      id: newPatient.id,
      entityType: 'Patient',
      action: 'CREATE',
      payload: {
        'id': newPatient.id,
        'mrn': newPatient.mrn,
        'fullName': newPatient.fullName,
        'phone': newPatient.phone,
        'lastVisitDate': newPatient.lastVisitDate,
      },
    );
  }

  static void addPrescription(String patientId, Prescription prescription) {
    final idx = _patients.indexWhere((p) => p.id == patientId);
    if (idx != -1) {
      final p = _patients[idx];
      final updatedRx = [prescription, ...p.prescriptions];
      _patients[idx] = Patient(
        id: p.id,
        mrn: p.mrn,
        fullName: p.fullName,
        middleName: p.middleName,
        dateOfBirth: p.dateOfBirth,
        gender: p.gender,
        phone: p.phone,
        address: p.address,
        referringDoctor: p.referringDoctor,
        medicalHistory: p.medicalHistory,
        allergies: p.allergies,
        previousDiagnoses: p.previousDiagnoses,
        previousPrescriptions: p.previousPrescriptions,
        prescriptions: updatedRx,
        encounters: p.encounters,
        lastVisitDate: p.lastVisitDate,
        totalVisits: p.totalVisits,
      );
      _saveToStorage();

      OfflineSyncService().enqueueMutation(
        id: prescription.id,
        entityType: 'Prescription',
        action: 'CREATE',
        payload: {
          'id': prescription.id,
          'patientId': patientId,
          'doctorName': prescription.doctorName,
          'date': prescription.date,
        },
      );
    }
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

  static void addEncounter(String patientId, Encounter encounter) {
    final patientIndex = _patients.indexWhere((p) => p.id == patientId);
    if (patientIndex != -1) {
      final existing = _patients[patientIndex];
      final updatedEncounters = [encounter, ...existing.encounters];
      _patients[patientIndex] = Patient(
        id: existing.id,
        mrn: existing.mrn,
        fullName: existing.fullName,
        middleName: existing.middleName,
        dateOfBirth: existing.dateOfBirth,
        gender: existing.gender,
        phone: existing.phone,
        address: existing.address,
        occupation: existing.occupation,
        phicNumber: existing.phicNumber,
        referringDoctor: existing.referringDoctor,
        medicalHistory: existing.medicalHistory,
        allergies: existing.allergies,
        previousDiagnoses: [encounter.diagnosis, ...existing.previousDiagnoses],
        previousPrescriptions: existing.previousPrescriptions,
        prescriptions: existing.prescriptions,
        encounters: updatedEncounters,
        lastVisitDate: encounter.date,
        totalVisits: existing.totalVisits + 1,
      );
      _saveToStorage();

      OfflineSyncService().enqueueMutation(
        id: encounter.id,
        entityType: 'Encounter',
        action: 'CREATE',
        payload: {
          'id': encounter.id,
          'patientId': patientId,
          'diagnosis': encounter.diagnosis,
          'date': encounter.date,
        },
      );
    }
  }
}