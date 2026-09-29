/// A person's part in a clinic. The leader created it and manages who is in it;
/// members work in it. Both see the same clinic data.
enum ClinicRole {
  leader('Leader'),
  member('Member');

  final String label;
  const ClinicRole(this.label);
}

/// A clinic or hospital: the workspace that owns a set of patient records.
/// One account can lead several clinics and be a member of others.
class Clinic {
  final String id;
  final String name;

  /// This account's role in the clinic.
  final ClinicRole role;

  const Clinic({required this.id, required this.name, required this.role});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role.name};

  static Clinic? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || id.isEmpty || name is! String || name.trim().isEmpty) return null;
    final role = ClinicRole.values.where((r) => r.name == raw['role']).firstOrNull ?? ClinicRole.member;
    return Clinic(id: id, name: name, role: role);
  }
}
