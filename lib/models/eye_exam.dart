// ignore_for_file: constant_identifier_names
enum EyeType { OD, OS, OU } // OD: Right Eye, OS: Left Eye, OU: Both Eyes

class Refraction {
  String sph; // Sphere e.g. "-2.20"
  String cyl; // Cylinder
  String axis; // Axis
  String? add; // Near ADD

  Refraction({
    this.sph = '0.00',
    this.cyl = '0.00',
    this.axis = '180',
    this.add,
  });

  Map<String, dynamic> toJson() => {
        'sph': sph,
        'cyl': cyl,
        'axis': axis,
        'add': add,
      };

  factory Refraction.fromJson(Map<String, dynamic> json) => Refraction(
        sph: json['sph'] as String? ?? '0.00',
        cyl: json['cyl'] as String? ?? '0.00',
        axis: json['axis'] as String? ?? '180',
        add: json['add'] as String?,
      );
}

class VisualAcuity {
  String uncorrected; // Distance VA (e.g. 20/20, HM, FC)
  String bestCorrected; // CC (Corrected Visual Acuity)
  String pinhole; // PH (Pinhole Visual Acuity)
  String oldCc; // Old Glasses Correction
  String ar; // Auto-Refractor (e.g. NO TARGET / NO REFRACT)
  String ak; // Auto-Keratometry

  VisualAcuity({
    this.uncorrected = '20/20',
    this.bestCorrected = '20/20',
    this.pinhole = 'HM',
    this.oldCc = '',
    this.ar = '',
    this.ak = '',
  });

  Map<String, dynamic> toJson() => {
        'uncorrected': uncorrected,
        'bestCorrected': bestCorrected,
        'pinhole': pinhole,
        'oldCc': oldCc,
        'ar': ar,
        'ak': ak,
      };

  factory VisualAcuity.fromJson(Map<String, dynamic> json) => VisualAcuity(
        uncorrected: json['uncorrected'] as String? ?? '20/20',
        bestCorrected: json['bestCorrected'] as String? ?? '20/20',
        pinhole: json['pinhole'] as String? ?? 'HM',
        oldCc: json['oldCc'] as String? ?? '',
        ar: json['ar'] as String? ?? '',
        ak: json['ak'] as String? ?? '',
      );
}

class EyeExamData {
  VisualAcuity acuity;
  Refraction refraction;
  String color; // Color perception e.g. "Normal / B-G"
  String iop; // Intraocular Pressure (mmHg)
  String iopMethod; // Goldmann, Tono-Pen, etc.
  String anglesGonioscopy; // Open / Narrow / Closed
  String cdrOn; // Cup-to-Disc Ratio & Optic Nerve (e.g. 0.3)
  String confrontationPeripheral; // WNL / Defect
  String vanHerick; // Anterior Chamber Depth (G1, G2, G3, G4, Wide)
  String slitLampNotes;
  String fundoscopyNotes;

  EyeExamData({
    required this.acuity,
    required this.refraction,
    this.color = 'Normal',
    this.iop = '15',
    this.iopMethod = 'Goldmann',
    this.anglesGonioscopy = 'Open',
    this.cdrOn = '0.3',
    this.confrontationPeripheral = 'WNL',
    this.vanHerick = 'G4 Wide',
    this.slitLampNotes = '',
    this.fundoscopyNotes = '',
  });

  Map<String, dynamic> toJson() => {
        'acuity': acuity.toJson(),
        'refraction': refraction.toJson(),
        'color': color,
        'iop': iop,
        'iopMethod': iopMethod,
        'anglesGonioscopy': anglesGonioscopy,
        'cdrOn': cdrOn,
        'confrontationPeripheral': confrontationPeripheral,
        'vanHerick': vanHerick,
        'slitLampNotes': slitLampNotes,
        'fundoscopyNotes': fundoscopyNotes,
      };

  factory EyeExamData.fromJson(Map<String, dynamic> json) => EyeExamData(
        acuity: json['acuity'] != null ? VisualAcuity.fromJson(json['acuity'] as Map<String, dynamic>) : VisualAcuity(),
        refraction: json['refraction'] != null ? Refraction.fromJson(json['refraction'] as Map<String, dynamic>) : Refraction(),
        color: json['color'] as String? ?? 'Normal',
        iop: json['iop'] as String? ?? '15',
        iopMethod: json['iopMethod'] as String? ?? 'Goldmann',
        anglesGonioscopy: json['anglesGonioscopy'] as String? ?? 'Open',
        cdrOn: json['cdrOn'] as String? ?? '0.3',
        confrontationPeripheral: json['confrontationPeripheral'] as String? ?? 'WNL',
        vanHerick: json['vanHerick'] as String? ?? 'G4 Wide',
        slitLampNotes: json['slitLampNotes'] as String? ?? '',
        fundoscopyNotes: json['fundoscopyNotes'] as String? ?? '',
      );
}