/// A clinic branch location and consultation schedule for prescription headers.
class ClinicBranch {
  final String id;
  String name;
  String address;
  String days;
  String hours;
  bool isArchived;
  DateTime? createdAt;
  final String? teamId;

  ClinicBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.days,
    required this.hours,
    this.isArchived = false,
    this.createdAt,
    this.teamId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'days': days,
        'hours': hours,
        'isArchived': isArchived,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (teamId != null && teamId!.isNotEmpty) 'teamId': teamId,
      };

  factory ClinicBranch.fromMap(Map<String, dynamic> map) => ClinicBranch(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? map['clinicName']?.toString() ?? '',
        address: map['address']?.toString() ?? map['location']?.toString() ?? '',
        days: map['days']?.toString() ?? '',
        hours: map['hours']?.toString() ?? '',
        isArchived: map['isArchived'] == true,
        createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
        teamId: map['teamId']?.toString(),
      );

  ClinicBranch copyWith({
    String? id,
    String? name,
    String? address,
    String? days,
    String? hours,
    bool? isArchived,
    DateTime? createdAt,
    String? teamId,
  }) {
    return ClinicBranch(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      days: days ?? this.days,
      hours: hours ?? this.hours,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      teamId: teamId ?? this.teamId,
    );
  }
}
