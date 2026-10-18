class PrescriptionItem {
  final String id;
  String medicationName;
  String strength;
  String dosage;
  String frequency;
  String duration;
  String instructions;

  PrescriptionItem({
    required this.id,
    required this.medicationName,
    required this.strength,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instructions,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicationName': medicationName,
        'strength': strength,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
        'instructions': instructions,
      };

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) => PrescriptionItem(
        id: json['id'] as String,
        medicationName: json['medicationName'] as String,
        strength: json['strength'] as String,
        dosage: json['dosage'] as String,
        frequency: json['frequency'] as String,
        duration: json['duration'] as String,
        instructions: json['instructions'] as String,
      );
}

class Prescription {
  final String id;
  final String patientId;
  final String encounterId;
  final String doctorName;
  final String date;
  final List<PrescriptionItem> items;
  final String notes;
  final String teamId;
  final String clinicBranch;
  final String followUpDate;

  Prescription({
    required this.id,
    required this.patientId,
    required this.encounterId,
    required this.doctorName,
    required this.date,
    required this.items,
    this.notes = '',
    this.teamId = '',
    this.clinicBranch = '',
    this.followUpDate = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'encounterId': encounterId,
        'doctorName': doctorName,
        'date': date,
        'items': items.map((i) => i.toJson()).toList(),
        'notes': notes,
        if (teamId.isNotEmpty) 'teamId': teamId,
        if (clinicBranch.isNotEmpty) 'clinicBranch': clinicBranch,
        if (followUpDate.isNotEmpty) 'followUpDate': followUpDate,
      };

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
        id: json['id'] as String,
        patientId: json['patientId'] as String,
        encounterId: json['encounterId'] as String,
        doctorName: json['doctorName'] as String,
        date: json['date'] as String,
        items: (json['items'] as List<dynamic>)
            .map((i) => PrescriptionItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        notes: json['notes'] as String? ?? '',
        teamId: json['teamId'] as String? ?? json['team_id'] as String? ?? '',
        clinicBranch: json['clinicBranch'] as String? ?? json['clinic_branch'] as String? ?? '',
        followUpDate: json['followUpDate'] as String? ?? json['follow_up_date'] as String? ?? '',
      );

  Prescription copyWith({
    String? id,
    String? patientId,
    String? encounterId,
    String? doctorName,
    String? date,
    List<PrescriptionItem>? items,
    String? notes,
    String? teamId,
    String? clinicBranch,
    String? followUpDate,
  }) =>
      Prescription(
        id: id ?? this.id,
        patientId: patientId ?? this.patientId,
        encounterId: encounterId ?? this.encounterId,
        doctorName: doctorName ?? this.doctorName,
        date: date ?? this.date,
        items: items ?? this.items,
        notes: notes ?? this.notes,
        teamId: teamId ?? this.teamId,
        clinicBranch: clinicBranch ?? this.clinicBranch,
        followUpDate: followUpDate ?? this.followUpDate,
      );
}
