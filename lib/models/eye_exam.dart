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
}