import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/clinic_branch.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import 'profile_store.dart';

class PrescriptionPdfService {
  /// Generates PDF binary bytes for an ophthalmic prescription matching RxPadWidget format
  static Future<Uint8List> generatePrescriptionPdf({
    Patient? patient,
    required List<PrescriptionItem> items,
    required String date,
    String? doctorName,
    String? specialization,
    String? licenseNo,
    String? ptrNo,
    String followUpDate = '_________________',
    String? clinic1Name,
    String? clinic1Location,
    String? clinic1Days,
    String? clinic1Hours,
    String? clinic2Name,
    String? clinic2Location,
    String? clinic2Days,
    String? clinic2Hours,
    String? clinic3Name,
    String? clinic3Location,
    String? clinic3Days,
    String? clinic3Hours,
  }) async {
    final profile = ProfileStore.instance;
    final effDoctorName = (doctorName != null && doctorName.isNotEmpty)
        ? doctorName
        : (profile.doctorName.text.isNotEmpty ? profile.doctorName.text : 'Dr. Sigrid T. Robillos');
    final effSpecialization = (specialization != null && specialization.isNotEmpty)
        ? specialization
        : (profile.specialization.text.isNotEmpty ? profile.specialization.text : 'OPHTHALMOLOGY / MICROSURGERY');
    final effLicenseNo = (licenseNo != null && licenseNo.isNotEmpty)
        ? licenseNo
        : (profile.license.text.isNotEmpty ? profile.license.text : '100064');
    final effPtrNo = (ptrNo != null && ptrNo.isNotEmpty)
        ? ptrNo
        : (profile.ptrNo.text.isNotEmpty ? profile.ptrNo.text : '_________________');

    final effClinic1Name = (clinic1Name != null && clinic1Name.isNotEmpty)
        ? clinic1Name
        : profile.clinic1Name.text;
    final effClinic1Location = (clinic1Location != null && clinic1Location.isNotEmpty)
        ? clinic1Location
        : profile.clinic1Location.text;
    final effClinic1Days = (clinic1Days != null && clinic1Days.isNotEmpty)
        ? clinic1Days
        : profile.clinic1Days.text;
    final effClinic1Hours = (clinic1Hours != null && clinic1Hours.isNotEmpty)
        ? clinic1Hours
        : profile.clinic1Hours.text;

    final effClinic2Name = (clinic2Name != null && clinic2Name.isNotEmpty)
        ? clinic2Name
        : profile.clinic2Name.text;
    final effClinic2Location = (clinic2Location != null && clinic2Location.isNotEmpty)
        ? clinic2Location
        : profile.clinic2Location.text;
    final effClinic2Days = (clinic2Days != null && clinic2Days.isNotEmpty)
        ? clinic2Days
        : profile.clinic2Days.text;
    final effClinic2Hours = (clinic2Hours != null && clinic2Hours.isNotEmpty)
        ? clinic2Hours
        : profile.clinic2Hours.text;

    final effClinic3Name = (clinic3Name != null && clinic3Name.isNotEmpty)
        ? clinic3Name
        : profile.clinic3Name.text;
    final effClinic3Location = (clinic3Location != null && clinic3Location.isNotEmpty)
        ? clinic3Location
        : profile.clinic3Location.text;
    final effClinic3Days = (clinic3Days != null && clinic3Days.isNotEmpty)
        ? clinic3Days
        : profile.clinic3Days.text;
    final effClinic3Hours = (clinic3Hours != null && clinic3Hours.isNotEmpty)
        ? clinic3Hours
        : profile.clinic3Hours.text;

    final pdf = pw.Document();

    final displayDate = date.isNotEmpty ? date : DateTime.now().toString().substring(0, 10);
    final patientName = patient?.fullName ?? '_____________________________________';
    final age = patient != null ? '${patient.age}' : '_____';
    final sex = patient?.gender.isNotEmpty == true ? patient!.gender : '_____';
    final address = patient?.address.isNotEmpty == true ? patient!.address : '_____________________________________';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. Doctor Header Title
                pw.Center(
                  child: pw.Text(
                    effDoctorName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    effSpecialization.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),

                // 2. Multi-Clinic Schedule Columns (Active branches)
                (() {
                  final hasExplicitClinics = clinic1Name != null || clinic2Name != null || clinic3Name != null;
                  final List<ClinicBranch> displayBranches;
                  if (hasExplicitClinics) {
                    displayBranches = [
                      if (effClinic1Name.isNotEmpty) ClinicBranch(id: 'c1', name: effClinic1Name, address: effClinic1Location, days: effClinic1Days, hours: effClinic1Hours),
                      if (effClinic2Name.isNotEmpty) ClinicBranch(id: 'c2', name: effClinic2Name, address: effClinic2Location, days: effClinic2Days, hours: effClinic2Hours),
                      if (effClinic3Name.isNotEmpty) ClinicBranch(id: 'c3', name: effClinic3Name, address: effClinic3Location, days: effClinic3Days, hours: effClinic3Hours),
                    ];
                  } else {
                    profile.syncControllersToBranches();
                    displayBranches = profile.activeBranches;
                  }

                  if (displayBranches.isEmpty) {
                    return pw.SizedBox.shrink();
                  }

                  return pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      for (final b in displayBranches)
                        pw.Expanded(
                          child: _buildClinicCol(
                            b.name,
                            b.address,
                            b.days,
                            b.hours,
                          ),
                        ),
                    ],
                  );
                })(),
                pw.SizedBox(height: 8),

                // Divider Line
                pw.Divider(color: PdfColors.blueGrey900, thickness: 1.2),
                pw.SizedBox(height: 8),

                // 3. Patient Info Section
                pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        pw.Text("Patient's Name ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                            ),
                            child: pw.Text(patientName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Text('Age ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Container(
                          width: 44,
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                          ),
                          child: pw.Text(age, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Text('Sex ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Container(
                          width: 44,
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                          ),
                          child: pw.Text(sex, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Text('Address ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                            ),
                            child: pw.Text(address, style: const pw.TextStyle(fontSize: 11)),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Text('Date ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Container(
                          width: 110,
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                          ),
                          child: pw.Text(displayDate, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // 4. Rx Symbol Header
                pw.Text(
                  'Rx',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 12),

                // 5. Prescribed Medications List
                pw.Expanded(
                  child: items.isEmpty
                      ? pw.Center(
                          child: pw.Text(
                            'No prescribed medications added yet.',
                            style: const pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                          ),
                        )
                      : pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: items.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final item = entry.value;
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 12),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    '$idx.  ${item.medicationName} (${item.strength})',
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.black),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(left: 18),
                                    child: pw.Text(
                                      'Sig: ${item.instructions.isNotEmpty ? item.instructions : "${item.dosage} - ${item.frequency} for ${item.duration}"}',
                                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey900),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                pw.SizedBox(height: 20),

                // 6. Footer Section (Follow up checkup & Doctor signature block)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Follow Up Check Up
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Follow Up Check Up:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          width: 140,
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                          ),
                          child: pw.Text(followUpDate, style: const pw.TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),

                    // Doctor Credentials & Signature Block
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          effDoctorName,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Container(
                          width: 180,
                          height: 1,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('License No. $effLicenseNo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text('PTR No. ', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text(effPtrNo, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildClinicCol(String name, String location, String days, String hours) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(name, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
        pw.Text(location, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
        pw.Text(days, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
        pw.Text(hours, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
      ],
    );
  }

  /// Triggers native print dialog for prescription
  static Future<void> printPrescription({
    Patient? patient,
    required List<PrescriptionItem> items,
    required String date,
    String? doctorName,
  }) async {
    final bytes = await generatePrescriptionPdf(
      patient: patient,
      items: items,
      date: date,
      doctorName: doctorName,
    );
    final fileName = 'Prescription_${(patient?.fullName ?? "Patient").replaceAll(' ', '_')}.pdf';
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: fileName,
    );
  }

  /// Exports and downloads the PDF file
  static Future<void> downloadPdf({
    Patient? patient,
    required List<PrescriptionItem> items,
    required String date,
    String? doctorName,
  }) async {
    final bytes = await generatePrescriptionPdf(
      patient: patient,
      items: items,
      date: date,
      doctorName: doctorName,
    );
    final fileName = 'Prescription_${(patient?.fullName ?? "Patient").replaceAll(' ', '_')}.pdf';
    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }
}
