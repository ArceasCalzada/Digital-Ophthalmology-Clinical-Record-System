import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clinic_branch.dart';
import 'auth_service.dart';
import 'firebase_gate.dart';
import 'team_service.dart';

/// The signed-in doctor's profile and the clinic details printed on prescriptions.
///
/// It lives outside any page so the Profile page (where it is edited), the
/// Prescription settings, and the account card in the sidebar all read the same
/// values. Values are persisted to SharedPreferences and synchronized with Firebase Firestore.
class ProfileStore extends ChangeNotifier {
  static final ProfileStore instance = ProfileStore._();
  ProfileStore._() {
    _initPersistence();
  }

  static const String _prefsKey = 'profile_store_settings';

  // Doctor profile.
  final doctorName = TextEditingController(text: 'Dr. Sigrid Robillos, MD');
  final doctorEmail = TextEditingController(text: 'dr.robillos@metroeye.com');
  final doctorPhone = TextEditingController(text: '+63 917 555 0192');
  final doctorTitle = TextEditingController(text: 'Attending Ophthalmologist');
  final specialization = TextEditingController(text: 'Cornea & Anterior Segment Specialist');
  final license = TextEditingController(text: 'PRC Lic. No. 091823');
  final ptrNo = TextEditingController(text: 'PTR No. 7821940');

  // Clinic information.
  final clinicName = TextEditingController(text: 'Metro Eye Center & Refractive Surgery');
  final clinicAddress = TextEditingController(text: 'Suite 402, Medical Arts Tower, Quezon City, Metro Manila');
  final clinicPhone = TextEditingController(text: '+63 2 8920 1100');
  final clinicEmail = TextEditingController(text: 'info@metroeyecenter.com');
  final clinicWebsite = TextEditingController(text: 'www.metroeyecenter.com');

  // Clinic Header Schedule Columns (3 branches for Rx pad)
  final clinic1Name = TextEditingController(text: 'St. Joseph Southern Bukidnon Hosp.');
  final clinic1Location = TextEditingController(text: 'Maramag, Bukidnon');
  final clinic1Days = TextEditingController(text: 'Monday & Tuesday');
  final clinic1Hours = TextEditingController(text: '9am - 12nn');

  final clinic2Name = TextEditingController(text: 'Malta Medical Center');
  final clinic2Location = TextEditingController(text: 'Toril, Davao City');
  final clinic2Days = TextEditingController(text: 'Thursday & Saturday');
  final clinic2Hours = TextEditingController(text: '10am - 12nn');

  final clinic3Name = TextEditingController(text: 'Adventist Hospital Davao');
  final clinic3Location = TextEditingController(text: 'Bangkal, Davao City');
  final clinic3Days = TextEditingController(text: 'Friday');
  final clinic3Hours = TextEditingController(text: '10am - 12nn');

  List<ClinicBranch> _branches = [
    ClinicBranch(
      id: 'branch-1',
      name: 'St. Joseph Southern Bukidnon Hosp.',
      address: 'Maramag, Bukidnon',
      days: 'Monday & Tuesday',
      hours: '9am - 12nn',
      isArchived: false,
    ),
    ClinicBranch(
      id: 'branch-2',
      name: 'Malta Medical Center',
      address: 'Toril, Davao City',
      days: 'Thursday & Saturday',
      hours: '10am - 12nn',
      isArchived: false,
    ),
    ClinicBranch(
      id: 'branch-3',
      name: 'Adventist Hospital Davao',
      address: 'Bangkal, Davao City',
      days: 'Friday',
      hours: '10am - 12nn',
      isArchived: false,
    ),
  ];

  List<ClinicBranch> get branches => List.unmodifiable(_branches);

  List<ClinicBranch> get activeBranches =>
      _branches.where((b) => !b.isArchived).toList();

  List<ClinicBranch> get archivedBranches =>
      _branches.where((b) => b.isArchived).toList();

  void _syncActiveBranchesToControllers() {
    final active = activeBranches;
    if (active.isNotEmpty) {
      clinic1Name.text = active[0].name;
      clinic1Location.text = active[0].address;
      clinic1Days.text = active[0].days;
      clinic1Hours.text = active[0].hours;
    } else {
      clinic1Name.text = '';
      clinic1Location.text = '';
      clinic1Days.text = '';
      clinic1Hours.text = '';
    }

    if (active.length > 1) {
      clinic2Name.text = active[1].name;
      clinic2Location.text = active[1].address;
      clinic2Days.text = active[1].days;
      clinic2Hours.text = active[1].hours;
    } else {
      clinic2Name.text = '';
      clinic2Location.text = '';
      clinic2Days.text = '';
      clinic2Hours.text = '';
    }

    if (active.length > 2) {
      clinic3Name.text = active[2].name;
      clinic3Location.text = active[2].address;
      clinic3Days.text = active[2].days;
      clinic3Hours.text = active[2].hours;
    } else {
      clinic3Name.text = '';
      clinic3Location.text = '';
      clinic3Days.text = '';
      clinic3Hours.text = '';
    }
  }

  void syncControllersToBranches() {
    final active = activeBranches;
    if (active.isNotEmpty && clinic1Name.text.isNotEmpty) {
      active[0].name = clinic1Name.text;
      active[0].address = clinic1Location.text;
      active[0].days = clinic1Days.text;
      active[0].hours = clinic1Hours.text;
    }
    if (active.length > 1 && clinic2Name.text.isNotEmpty) {
      active[1].name = clinic2Name.text;
      active[1].address = clinic2Location.text;
      active[1].days = clinic2Days.text;
      active[1].hours = clinic2Hours.text;
    }
    if (active.length > 2 && clinic3Name.text.isNotEmpty) {
      active[2].name = clinic3Name.text;
      active[2].address = clinic3Location.text;
      active[2].days = clinic3Days.text;
      active[2].hours = clinic3Hours.text;
    }
  }

  Future<void> addBranch({
    required String name,
    required String address,
    required String days,
    required String hours,
    String? teamId,
  }) async {
    if (TeamService.instance.isAssistant) return;
    final newBranch = ClinicBranch(
      id: 'branch-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      address: address.trim(),
      days: days.trim(),
      hours: hours.trim(),
      isArchived: false,
      createdAt: DateTime.now(),
    );
    _branches.add(newBranch);
    _syncActiveBranchesToControllers();
    notifyListeners();
    await saveToFirestore(teamId: teamId);
  }

  Future<void> archiveBranch(String branchId, {String? teamId}) async {
    if (TeamService.instance.isAssistant) return;
    final index = _branches.indexWhere((b) => b.id == branchId);
    if (index != -1) {
      _branches[index].isArchived = true;
      _syncActiveBranchesToControllers();
      notifyListeners();
      await saveToFirestore(teamId: teamId);
    }
  }

  Future<void> restoreBranch(String branchId, {String? teamId}) async {
    if (TeamService.instance.isAssistant) return;
    final index = _branches.indexWhere((b) => b.id == branchId);
    if (index != -1) {
      _branches[index].isArchived = false;
      _syncActiveBranchesToControllers();
      notifyListeners();
      await saveToFirestore(teamId: teamId);
    }
  }

  Future<void> updateBranch(ClinicBranch updated, {String? teamId}) async {
    if (TeamService.instance.isAssistant) return;
    final index = _branches.indexWhere((b) => b.id == updated.id);
    if (index != -1) {
      _branches[index] = updated;
      _syncActiveBranchesToControllers();
      notifyListeners();
      await saveToFirestore(teamId: teamId);
    }
  }

  void resetToDefaultBranches() {
    _resetBranches();
    notifyListeners();
  }

  void _resetBranches() {
    _branches = [
      ClinicBranch(
        id: 'branch-1',
        name: 'St. Joseph Southern Bukidnon Hosp.',
        address: 'Maramag, Bukidnon',
        days: 'Monday & Tuesday',
        hours: '9am - 12nn',
        isArchived: false,
      ),
      ClinicBranch(
        id: 'branch-2',
        name: 'Malta Medical Center',
        address: 'Toril, Davao City',
        days: 'Thursday & Saturday',
        hours: '10am - 12nn',
        isArchived: false,
      ),
      ClinicBranch(
        id: 'branch-3',
        name: 'Adventist Hospital Davao',
        address: 'Bangkal, Davao City',
        days: 'Friday',
        hours: '10am - 12nn',
        isArchived: false,
      ),
    ];
    _syncActiveBranchesToControllers();
  }

  void _initPersistence() {
    loadFromPreferences();
  }

  /// Validates required prescription settings.
  /// Returns null if valid, or an error string if invalid.
  String? validatePrescriptionSettings() {
    if (doctorName.text.trim().isEmpty) {
      return 'Doctor Name is required and cannot be empty.';
    }
    if (license.text.trim().isEmpty) {
      return 'License Number is required and cannot be empty.';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    syncControllersToBranches();
    return {
      'doctorName': doctorName.text.trim(),
      'doctorEmail': doctorEmail.text.trim(),
      'doctorPhone': doctorPhone.text.trim(),
      'doctorTitle': doctorTitle.text.trim(),
      'specialization': specialization.text.trim(),
      'license': license.text.trim(),
      'ptrNo': ptrNo.text.trim(),
      'clinicName': clinicName.text.trim(),
      'clinicAddress': clinicAddress.text.trim(),
      'clinicPhone': clinicPhone.text.trim(),
      'clinicEmail': clinicEmail.text.trim(),
      'clinicWebsite': clinicWebsite.text.trim(),
      'clinic1Name': clinic1Name.text.trim(),
      'clinic1Location': clinic1Location.text.trim(),
      'clinic1Days': clinic1Days.text.trim(),
      'clinic1Hours': clinic1Hours.text.trim(),
      'clinic2Name': clinic2Name.text.trim(),
      'clinic2Location': clinic2Location.text.trim(),
      'clinic2Days': clinic2Days.text.trim(),
      'clinic2Hours': clinic2Hours.text.trim(),
      'clinic3Name': clinic3Name.text.trim(),
      'clinic3Location': clinic3Location.text.trim(),
      'clinic3Days': clinic3Days.text.trim(),
      'clinic3Hours': clinic3Hours.text.trim(),
      'branches': _branches.map((b) => b.toMap()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  void fromMap(Map<String, dynamic> data) {
    if (data['doctorName'] != null) doctorName.text = data['doctorName'].toString();
    if (data['doctorEmail'] != null) doctorEmail.text = data['doctorEmail'].toString();
    if (data['doctorPhone'] != null) doctorPhone.text = data['doctorPhone'].toString();
    if (data['doctorTitle'] != null) doctorTitle.text = data['doctorTitle'].toString();
    if (data['specialization'] != null) specialization.text = data['specialization'].toString();
    if (data['license'] != null) license.text = data['license'].toString();
    if (data['ptrNo'] != null) ptrNo.text = data['ptrNo'].toString();
    if (data['clinicName'] != null) clinicName.text = data['clinicName'].toString();
    if (data['clinicAddress'] != null) clinicAddress.text = data['clinicAddress'].toString();
    if (data['clinicPhone'] != null) clinicPhone.text = data['clinicPhone'].toString();
    if (data['clinicEmail'] != null) clinicEmail.text = data['clinicEmail'].toString();
    if (data['clinicWebsite'] != null) clinicWebsite.text = data['clinicWebsite'].toString();

    if (data['branches'] != null && (data['branches'] as List).isNotEmpty) {
      _branches = (data['branches'] as List)
          .map((b) => ClinicBranch.fromMap(Map<String, dynamic>.from(b as Map)))
          .toList();
      _syncActiveBranchesToControllers();
    } else {
      if (data['clinic1Name'] != null) clinic1Name.text = data['clinic1Name'].toString();
      if (data['clinic1Location'] != null) clinic1Location.text = data['clinic1Location'].toString();
      if (data['clinic1Days'] != null) clinic1Days.text = data['clinic1Days'].toString();
      if (data['clinic1Hours'] != null) clinic1Hours.text = data['clinic1Hours'].toString();

      if (data['clinic2Name'] != null) clinic2Name.text = data['clinic2Name'].toString();
      if (data['clinic2Location'] != null) clinic2Location.text = data['clinic2Location'].toString();
      if (data['clinic2Days'] != null) clinic2Days.text = data['clinic2Days'].toString();
      if (data['clinic2Hours'] != null) clinic2Hours.text = data['clinic2Hours'].toString();

      if (data['clinic3Name'] != null) clinic3Name.text = data['clinic3Name'].toString();
      if (data['clinic3Location'] != null) clinic3Location.text = data['clinic3Location'].toString();
      if (data['clinic3Days'] != null) clinic3Days.text = data['clinic3Days'].toString();
      if (data['clinic3Hours'] != null) clinic3Hours.text = data['clinic3Hours'].toString();

      _branches = [
        ClinicBranch(
          id: 'branch-1',
          name: clinic1Name.text,
          address: clinic1Location.text,
          days: clinic1Days.text,
          hours: clinic1Hours.text,
          isArchived: false,
        ),
        ClinicBranch(
          id: 'branch-2',
          name: clinic2Name.text,
          address: clinic2Location.text,
          days: clinic2Days.text,
          hours: clinic2Hours.text,
          isArchived: false,
        ),
        ClinicBranch(
          id: 'branch-3',
          name: clinic3Name.text,
          address: clinic3Location.text,
          days: clinic3Days.text,
          hours: clinic3Hours.text,
          isArchived: false,
        ),
      ];
    }

    notifyListeners();
  }

  Future<void> saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(toMap()));
    } catch (_) {}
  }

  Future<void> loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        fromMap(decoded);
      }
    } catch (_) {}
  }

  /// Saves settings both locally and to Firestore backend.
  Future<void> saveToFirestore({String? teamId}) async {
    if (TeamService.instance.isAssistant) {
      return; // Assistants cannot execute write operations on prescription layouts, doctor profiles, or clinic branch configurations
    }
    await saveToPreferences();
    notifyListeners();

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;

    try {
      final data = FirebaseGate.encode(toMap());
      // Save to global prescription settings
      await firestore.collection('settings').doc('prescription').set(data, SetOptions(merge: true));

      // Also save to active team's settings if teamId is provided
      if (teamId != null && teamId.isNotEmpty) {
        await firestore
            .collection('teams')
            .doc(teamId)
            .collection('settings')
            .doc('prescription')
            .set(data, SetOptions(merge: true));
        await firestore.collection('teams').doc(teamId).set({
          'prescriptionSettings': data,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// Loads prescription settings from Firestore with fallback to SharedPreferences.
  Future<void> loadFromFirestore({String? teamId}) async {
    await loadFromPreferences();

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;

    try {
      DocumentSnapshot<Map<String, dynamic>>? snap;
      if (teamId != null && teamId.isNotEmpty) {
        snap = await firestore
            .collection('teams')
            .doc(teamId)
            .collection('settings')
            .doc('prescription')
            .get();
        if (!snap.exists) {
          final teamSnap = await firestore.collection('teams').doc(teamId).get();
          if (teamSnap.exists && teamSnap.data()?['prescriptionSettings'] != null) {
            final tData = FirebaseGate.decode(teamSnap.data()!['prescriptionSettings'] as Map<String, dynamic>);
            fromMap(tData);
            await saveToPreferences();
            return;
          }
        }
      }

      if (snap == null || !snap.exists) {
        snap = await firestore.collection('settings').doc('prescription').get();
      }

      if (snap.exists && snap.data() != null) {
        final decoded = FirebaseGate.decode(snap.data()!);
        fromMap(decoded);
        await saveToPreferences();
      }
    } catch (_) {}
  }

  /// Updates ProfileStore fields based on the currently logged in user.
  void syncWithUser(AuthUser? user, {String? fullName}) {
    if (user == null) return;
    if (user.email != null && user.email!.isNotEmpty) {
      doctorEmail.text = user.email!;
    }
    final name = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim()
        : (user.displayName != null && user.displayName!.trim().isNotEmpty
            ? user.displayName!.trim()
            : (user.email != null && user.email!.isNotEmpty
                ? user.email!.split('@').first
                : ''));
    if (name.isNotEmpty) {
      doctorName.text = name.startsWith('Dr.') ? name : 'Dr. $name';
    }
    notifyListeners();
  }

  /// Resets user profile details on logout.
  void reset() {
    doctorName.text = 'Dr. Sigrid Robillos, MD';
    doctorEmail.text = 'dr.robillos@metroeye.com';
    _resetBranches();
    notifyListeners();
  }

  /// Tells listeners that a Save was pressed on the Profile or Settings page.
  void save() => notifyListeners();

  /// "Dr. Sigrid Robillos, MD" -> "SR": the first letters of the first two name words,
  /// ignoring titles ("Dr.") and credentials after a comma ("MD").
  static String initialsOf(String name) {
    final words = name
        .split(',')
        .first
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !RegExp(r'^(dr|mr|mrs|ms|prof)\.?$', caseSensitive: false).hasMatch(w))
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words.first[0] + words[1][0]).toUpperCase();
  }
}

