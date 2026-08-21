import 'encounter.dart';
import 'eye_exam.dart';
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
  final String dateOfBirth; // YYYY-MM-DD
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
    if (dob == null) return 45;
    final now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }
}

class PatientRepository {
  static final List<Prescription> _initialPrescriptions = [
    Prescription(
      id: 'rx-2026-001',
      patientId: 'pat-001',
      encounterId: 'enc-2026-0510',
      doctorName: 'Dr. Sigrid Robillos, MD',
      date: '2026-05-10',
      items: [
        PrescriptionItem(
          id: 'item-1',
          medicationName: 'Latanoprost 0.005% Ophthalmic Solution',
          strength: '0.005%',
          dosage: '1 drop',
          frequency: 'Once daily at bedtime',
          duration: '30 days',
          instructions: 'Instill 1 drop in both eyes (OU) every night before sleep.',
        ),
        PrescriptionItem(
          id: 'item-2',
          medicationName: 'Carboxymethylcellulose 0.5% Artificial Tears',
          strength: '0.5%',
          dosage: '1-2 drops',
          frequency: '4 times daily PRN',
          duration: '60 days',
          instructions: 'Instill 1 to 2 drops in both eyes as needed for dry eye relief.',
        ),
      ],
    ),
  ];

  static final List<Patient> _patients = [
    Patient(
      id: 'pat-asturias',
      mrn: 'MRN-2026-7302',
      fullName: 'Edgardo Asturias',
      middleName: 'Perez',
      dateOfBirth: '1963-05-07',
      gender: 'Male',
      phone: '+63 917 882 1963',
      address: 'Apas, Davao City',
      occupation: 'Civil Servant',
      phicNumber: '19-02581024-8',
      referringDoctor: 'Dr. Ramon Santos',
      medicalHistory: ['Hypertension (HPN)', 'Cholesterol det (Dyslipidemia)'],
      allergies: ['No Known Drug Allergies (NKDA)'],
      previousDiagnoses: ['Mature Cataract OS', 'Glaucoma Suspect OU'],
      previousPrescriptions: ['Tropicamide 0.5% + Phenylephrine 0.5% Drops - 1 drop OU PRN'],
      prescriptions: [],
      lastVisitDate: '2026-07-30',
      totalVisits: 1,
      encounters: [
        Encounter(
          id: 'enc-2026-0730',
          patientId: 'pat-asturias',
          date: '2026-07-30',
          doctorName: 'Dr. Sigrid Robillos, MD',
          chiefComplaint: 'OS BOV x 1 year. Came in w/ silingan. No family.',
          examOD: EyeExamData(
            acuity: VisualAcuity(uncorrected: 'HM', pinhole: 'HM', bestCorrected: 'Plano', oldCc: 'Plano', ar: 'NO TARGET', ak: 'NO TARGET'),
            refraction: Refraction(sph: '0.00', cyl: '0.00', axis: '180'),
            color: 'B / G',
            iop: '16',
            anglesGonioscopy: 'Open',
            cdrOn: '0.4',
            confrontationPeripheral: 'WNL',
            vanHerick: 'G4 Wide',
            slitLampNotes: 'Clear cornea, anterior chamber deep and quiet.',
            fundoscopyNotes: 'Clear view OD, C/D ratio 0.4.',
          ),
          examOS: EyeExamData(
            acuity: VisualAcuity(uncorrected: 'HM', pinhole: 'HM', bestCorrected: 'Plano', oldCc: 'Plano', ar: 'NO TARGET', ak: 'NO TARGET'),
            refraction: Refraction(sph: '0.00', cyl: '0.00', axis: '180'),
            color: 'B / G',
            iop: '18',
            anglesGonioscopy: 'Open',
            cdrOn: '0.5',
            confrontationPeripheral: 'WNL',
            vanHerick: 'G4 Wide',
            slitLampNotes: 'Mature brunescent nuclear cataract OS. Poor red reflex.',
            fundoscopyNotes: 'Hazy view OS secondary to mature lens opacity.',
          ),
          diagnosis: 'Mature Cataract OS',
          treatmentPlan: 'Dilate OU. To BSC - PHIC only.',
        ),
      ],
    ),
    Patient(
      id: 'pat-001',
      mrn: 'MRN-2026-9041',
      fullName: 'Juan Dela Cruz',
      middleName: 'Reyes',
      dateOfBirth: '1978-04-12',
      gender: 'Male',
      phone: '+63 917 555 0192',
      address: '124 Rizal Ave, Quezon City, Metro Manila',
      referringDoctor: 'Dr. Ramon Santos',
      medicalHistory: ['Type 2 Diabetes Mellitus', 'Hypertension (Controlled)', 'No Prior Eye Surgery'],
      allergies: ['Penicillin', 'Sulfa Drugs'],
      previousDiagnoses: ['Mild Non-Proliferative Diabetic Retinopathy (NPDR)', 'Cortical Cataract OD'],
      previousPrescriptions: ['Latanoprost 0.005% Eye Drops - 1 drop OU at bedtime', 'Carboxymethylcellulose 0.5% Artificial Tears'],
      prescriptions: _initialPrescriptions,
      lastVisitDate: '2026-05-10',
      totalVisits: 3,
      encounters: [
        Encounter(
          id: 'enc-2026-0510',
          patientId: 'pat-001',
          date: '2026-05-10',
          doctorName: 'Dr. Sigrid Robillos, MD',
          chiefComplaint: 'Blurred vision in right eye when reading, mild dry eye sensation.',
          examOD: EyeExamData(
            acuity: VisualAcuity(uncorrected: '20/50', bestCorrected: '20/25', pinhole: '20/20'),
            refraction: Refraction(sph: '-2.50', cyl: '-0.75', axis: '090', add: '+2.00'),
            iop: '18',
            iopMethod: 'Goldmann',
            slitLampNotes: 'Mild nuclear sclerosis, clear cornea.',
            fundoscopyNotes: 'Scattered microaneurysms in posterior pole OD.',
          ),
          examOS: EyeExamData(
            acuity: VisualAcuity(uncorrected: '20/30', bestCorrected: '20/20'),
            refraction: Refraction(sph: '-2.00', cyl: '-0.50', axis: '085', add: '+2.00'),
            iop: '16',
            iopMethod: 'Goldmann',
            slitLampNotes: 'Clear cornea and crystalline lens.',
            fundoscopyNotes: 'Normal optic disc C/D 0.35, sharp margins.',
          ),
          diagnosis: 'Mild Non-Proliferative Diabetic Retinopathy (NPDR) OD',
          treatmentPlan: 'Glycemic control optimization. Follow up in 3 months for dilated fundus exam.',
        ),
      ],
    ),
    Patient(
      id: 'pat-002',
      mrn: 'MRN-2026-8812',
      fullName: 'Maria Santos',
      middleName: 'Gonzales',
      dateOfBirth: '1962-11-23',
      gender: 'Female',
      phone: '+63 918 222 9011',
      address: '45 Katipunan Ave, Quezon City',
      medicalHistory: ['Primary Open-Angle Glaucoma (POAG)', 'Hypertension'],
      allergies: ['No Known Drug Allergies (NKDA)'],
      previousDiagnoses: ['Bilateral POAG', 'Nuclear Sclerotic Cataract 2+ OU'],
      previousPrescriptions: ['Bimatoprost 0.01% Drops - 1 drop OU bedtime', 'Brimonidine 0.2% Drops - 1 drop BID'],
      prescriptions: [],
      lastVisitDate: '2026-07-02',
      totalVisits: 5,
      encounters: [],
    ),
  ];

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
    }
  }

  static List<TodayPatientQueue> getTodayQueue() {
    return [
      TodayPatientQueue(
        patient: _patients.first,
        time: '09:00 AM',
        visitType: 'Clinical Consultation Sheet',
        status: 'In Examination',
      ),
      TodayPatientQueue(
        patient: _patients.length > 1 ? _patients[1] : _patients.first,
        time: '09:30 AM',
        visitType: 'Follow-up Examination',
        status: 'Waiting',
      ),
      TodayPatientQueue(
        patient: _patients.length > 2 ? _patients[2] : _patients.first,
        time: '10:15 AM',
        visitType: 'Glaucoma Consultation',
        status: 'Waiting',
      ),
    ];
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
    }
  }
}