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

  Prescription({
    required this.id,
    required this.patientId,
    required this.encounterId,
    required this.doctorName,
    required this.date,
    required this.items,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'encounterId': encounterId,
        'doctorName': doctorName,
        'date': date,
        'items': items.map((i) => i.toJson()).toList(),
        'notes': notes,
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
      );
}
