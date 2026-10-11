import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../models/prescription.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';

/// Authentic Ophthalmic Prescription Pad Widget matching Dr. Sigrid T. Robillos format
class RxPadWidget extends StatelessWidget {
  final Patient? patient;
  final List<PrescriptionItem> items;
  final String date;
  final String? doctorName;
  final String? specialization;
  final String? licenseNo;
  final String? ptrNo;
  final String followUpDate;
  final bool showBorder;
  final String? clinic1Name;
  final String? clinic1Location;
  final String? clinic1Days;
  final String? clinic1Hours;
  final String? clinic2Name;
  final String? clinic2Location;
  final String? clinic2Days;
  final String? clinic2Hours;
  final String? clinic3Name;
  final String? clinic3Location;
  final String? clinic3Days;
  final String? clinic3Hours;

  const RxPadWidget({
    super.key,
    this.patient,
    required this.items,
    required this.date,
    this.doctorName,
    this.specialization,
    this.licenseNo,
    this.ptrNo,
    this.followUpDate = '_________________',
    this.showBorder = true,
    this.clinic1Name,
    this.clinic1Location,
    this.clinic1Days,
    this.clinic1Hours,
    this.clinic2Name,
    this.clinic2Location,
    this.clinic2Days,
    this.clinic2Hours,
    this.clinic3Name,
    this.clinic3Location,
    this.clinic3Days,
    this.clinic3Hours,
  });

  @override
  Widget build(BuildContext context) {
    final profile = ProfileStore.instance;
    final effDoctorName = (doctorName != null && doctorName!.isNotEmpty)
        ? doctorName!
        : (profile.doctorName.text.isNotEmpty ? profile.doctorName.text : 'Dr. Sigrid T. Robillos');
    final effSpecialization = (specialization != null && specialization!.isNotEmpty)
        ? specialization!
        : (profile.specialization.text.isNotEmpty ? profile.specialization.text : 'OPHTHALMOLOGY / MICROSURGERY');
    final effLicenseNo = (licenseNo != null && licenseNo!.isNotEmpty)
        ? licenseNo!
        : (profile.license.text.isNotEmpty ? profile.license.text : '100064');
    final effPtrNo = (ptrNo != null && ptrNo!.isNotEmpty)
        ? ptrNo!
        : (profile.ptrNo.text.isNotEmpty ? profile.ptrNo.text : '_________________');

    final effClinic1Name = (clinic1Name != null && clinic1Name!.isNotEmpty)
        ? clinic1Name!
        : profile.clinic1Name.text;
    final effClinic1Location = (clinic1Location != null && clinic1Location!.isNotEmpty)
        ? clinic1Location!
        : profile.clinic1Location.text;
    final effClinic1Days = (clinic1Days != null && clinic1Days!.isNotEmpty)
        ? clinic1Days!
        : profile.clinic1Days.text;
    final effClinic1Hours = (clinic1Hours != null && clinic1Hours!.isNotEmpty)
        ? clinic1Hours!
        : profile.clinic1Hours.text;

    final effClinic2Name = (clinic2Name != null && clinic2Name!.isNotEmpty)
        ? clinic2Name!
        : profile.clinic2Name.text;
    final effClinic2Location = (clinic2Location != null && clinic2Location!.isNotEmpty)
        ? clinic2Location!
        : profile.clinic2Location.text;
    final effClinic2Days = (clinic2Days != null && clinic2Days!.isNotEmpty)
        ? clinic2Days!
        : profile.clinic2Days.text;
    final effClinic2Hours = (clinic2Hours != null && clinic2Hours!.isNotEmpty)
        ? clinic2Hours!
        : profile.clinic2Hours.text;

    final effClinic3Name = (clinic3Name != null && clinic3Name!.isNotEmpty)
        ? clinic3Name!
        : profile.clinic3Name.text;
    final effClinic3Location = (clinic3Location != null && clinic3Location!.isNotEmpty)
        ? clinic3Location!
        : profile.clinic3Location.text;
    final effClinic3Days = (clinic3Days != null && clinic3Days!.isNotEmpty)
        ? clinic3Days!
        : profile.clinic3Days.text;
    final effClinic3Hours = (clinic3Hours != null && clinic3Hours!.isNotEmpty)
        ? clinic3Hours!
        : profile.clinic3Hours.text;

    final displayDate = date.isNotEmpty ? date : DateTime.now().toString().substring(0, 10);
    final patientName = patient?.fullName ?? '_____________________________________';
    final age = patient != null ? '${patient!.age}' : '_____';
    final sex = patient?.gender.isNotEmpty == true ? patient!.gender : '_____';
    final address = patient?.address.isNotEmpty == true ? patient!.address : '_____________________________________';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(showBorder ? 12 : 0),
        border: showBorder ? Border.all(color: AppTheme.borderColor, width: 1.5) : null,
        boxShadow: showBorder
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: Offset(0, 4),
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
              effDoctorName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: 2),

          // Specialization Sub-header
          Center(
            child: Text(
              effSpecialization.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: 1.2,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          SizedBox(height: 12),

          // 2. Multi-Clinic Schedule Columns (3 Columns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildClinicScheduleCol(
                  effClinic1Name,
                  effClinic1Location,
                  effClinic1Days,
                  effClinic1Hours,
                ),
              ),
              Expanded(
                child: _buildClinicScheduleCol(
                  effClinic2Name,
                  effClinic2Location,
                  effClinic2Days,
                  effClinic2Hours,
                ),
              ),
              Expanded(
                child: _buildClinicScheduleCol(
                  effClinic3Name,
                  effClinic3Location,
                  effClinic3Days,
                  effClinic3Hours,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // Divider Line
          Divider(color: Color(0xFF0F172A), thickness: 1.2),
          SizedBox(height: 8),

          // 3. Patient Information Section
          Column(
            children: [
              Row(
                children: [
                  Text("Patient's Name ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                      ),
                      child: Text(patientName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Age ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  Container(
                    width: 44,
                    padding: EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                    ),
                    child: Text(age, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ),
                  SizedBox(width: 12),
                  Text('Sex ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  Container(
                    width: 44,
                    padding: EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                    ),
                    child: Text(sex, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('Address ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                      ),
                      child: Text(address, style: TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Date ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  Container(
                    width: 110,
                    padding: EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                    ),
                    child: Text(displayDate, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),

          // 4. Rx Symbol Header
          Text(
            'Rx',
            style: TextStyle(
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 12),

          // 5. Prescribed Medications Body List
          Container(
            constraints: BoxConstraints(minHeight: 160),
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: items.isEmpty
                ? Center(
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
                        padding: EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$idx.  ${item.medicationName} (${item.strength})',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Padding(
                              padding: EdgeInsets.only(left: 20),
                              child: Text(
                                'Sig: ${item.instructions.isNotEmpty ? item.instructions : "${item.dosage} - ${item.frequency} for ${item.duration}"}',
                                style: TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          SizedBox(height: 20),

          // 6. Footer Section (Follow up left, Signature right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: Follow Up Check Up
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Follow Up Check Up:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Container(
                      width: 130,
                      padding: EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 1)),
                      ),
                      child: Text(followUpDate, style: TextStyle(fontSize: 11, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              // Right: Doctor Credentials & Signature Block
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      effDoctorName,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      width: 180,
                      height: 1,
                      color: Color(0xFF0F172A),
                    ),
                    SizedBox(height: 4),
                    Text('License No. $effLicenseNo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('PTR No. ', style: TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
                        Flexible(child: Text(effPtrNo, style: TextStyle(fontSize: 11, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
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
        Text(name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: Color(0xFF0F172A))),
        Text(location, textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, color: Color(0xFF475569))),
        Text(days, textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        Text(hours, textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, color: Color(0xFF475569))),
      ],
    );
  }
}
