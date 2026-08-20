import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../theme/app_theme.dart';

/// Authentic Ophthalmic Prescription Pad Widget matching Dr. Sigrid T. Robillos format
class RxPadWidget extends StatelessWidget {
  final Patient? patient;
  final List<PrescriptionItem> items;
  final String date;
  final String doctorName;
  final String specialization;
  final String licenseNo;
  final String ptrNo;
  final String followUpDate;
  final bool showBorder;

  const RxPadWidget({
    super.key,
    this.patient,
    required this.items,
    required this.date,
    this.doctorName = 'Dr. Sigrid T. Robillos',
    this.specialization = 'OPHTHALMOLOGY / MICROSURGERY',
    this.licenseNo = '100064',
    this.ptrNo = '_________________',
    this.followUpDate = '_________________',
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayDate = date.isNotEmpty ? date : DateTime.now().toString().substring(0, 10);
    final patientName = patient?.fullName ?? '_____________________________________';
    final age = patient != null ? '${patient!.age}' : '_____';
    final sex = patient?.gender.isNotEmpty == true ? patient!.gender : '_____';
    final address = patient?.address.isNotEmpty == true ? patient!.address : '_____________________________________';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(showBorder ? 12 : 0),
        border: showBorder ? Border.all(color: AppTheme.borderColor, width: 1.5) : null,
        boxShadow: showBorder
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Doctor Name Title Header (Top Centered)
          Center(
            child: Text(
              doctorName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),

          // Specialization Sub-header
          Center(
            child: Text(
              specialization.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: 1.2,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Multi-Clinic Schedule Columns (3 Columns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildClinicScheduleCol(
                  'St. Joseph Southern Bukidnon Hosp.',
                  'Maramag, Bukidnon',
                  'Monday & Tuesday',
                  '9am - 12nn',
                ),
              ),
              Expanded(
                child: _buildClinicScheduleCol(
                  'Malta Medical Center',
                  'Toril, Davao City',
                  'Thursday & Saturday',
                  '10am - 12nn',
                ),
              ),
              Expanded(
                child: _buildClinicScheduleCol(
                  'Adventist Hospital Davao',
                  'Bangkal, Davao City',
                  'Friday',
                  '10am - 12nn',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Divider Line
          const Divider(color: Color(0xFF0F172A), thickness: 1.2),
          const SizedBox(height: 8),

          // 3. Patient Information Section
          Column(
            children: [
              Row(
                children: [
                  const Text("Patient's Name ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 2),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                      ),
                      child: Text(patientName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Age ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  Container(
                    width: 44,
                    padding: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                    ),
                    child: Text(age, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ),
                  const SizedBox(width: 12),
                  const Text('Sex ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  Container(
                    width: 44,
                    padding: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                    ),
                    child: Text(sex, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Address ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 2),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                      ),
                      child: Text(address, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Date ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  Container(
                    width: 110,
                    padding: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                    ),
                    child: Text(displayDate, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Rx Symbol Header
          const Text(
            'Rx',
            style: TextStyle(
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // 5. Prescribed Medications Body List
          Container(
            constraints: const BoxConstraints(minHeight: 160),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'No prescribed medications added yet.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$idx.  ${item.medicationName} (${item.strength})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Text(
                                'Sig: ${item.instructions.isNotEmpty ? item.instructions : "${item.dosage} - ${item.frequency} for ${item.duration}"}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),

          // 6. Footer Section (Follow up left, Signature right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: Follow Up Check Up
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Follow Up Check Up:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Container(
                    width: 140,
                    padding: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                    ),
                    child: Text(followUpDate, style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
                  ),
                ],
              ),

              // Right: Doctor Credentials & Signature Block
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Sigrid Robillos-Calzada M.D.',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  Container(
                    width: 190,
                    height: 1,
                    color: const Color(0xFF0F172A),
                  ),
                  const SizedBox(height: 4),
                  Text('License No. $licenseNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('PTR No. ', style: TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
                      Text(ptrNo, style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClinicScheduleCol(String name, String location, String days, String hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: Color(0xFF0F172A))),
        Text(location, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8.5, color: Color(0xFF475569))),
        Text(days, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        Text(hours, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8.5, color: Color(0xFF475569))),
      ],
    );
  }
}
