import 'package:flutter/material.dart';
import 'auth_service.dart';

/// The signed-in doctor's profile and the clinic details printed on prescriptions.
///
/// It lives outside any page so the Profile page (where it is edited), the
/// Prescription settings, and the account card in the sidebar all read the same
/// values. Values are held in memory only for now; they reset when the app closes.
class ProfileStore extends ChangeNotifier {
  static final ProfileStore instance = ProfileStore._();
  ProfileStore._();

  // Doctor profile.
  final doctorName = TextEditingController(text: 'Dr. Sigrid Robillos, MD');
  final doctorEmail = TextEditingController(text: 'dr.robillos@metroeye.com');
  final doctorPhone = TextEditingController(text: '+63 917 555 0192');
  final doctorTitle = TextEditingController(text: 'Attending Ophthalmologist');
  final specialization = TextEditingController(text: 'Cornea & Anterior Segment Specialist');
  final license = TextEditingController(text: 'PRC Lic. No. 091823');

  // Clinic information.
  final clinicName = TextEditingController(text: 'Metro Eye Center & Refractive Surgery');
  final clinicAddress = TextEditingController(text: 'Suite 402, Medical Arts Tower, Quezon City, Metro Manila');
  final clinicPhone = TextEditingController(text: '+63 2 8920 1100');
  final clinicEmail = TextEditingController(text: 'info@metroeyecenter.com');
  final clinicWebsite = TextEditingController(text: 'www.metroeyecenter.com');

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
    notifyListeners();
  }

  /// Tells listeners (the sidebar card) that a Save was pressed on the Profile page.
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
