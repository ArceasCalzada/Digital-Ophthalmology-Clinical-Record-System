import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final Function(Patient)? onSelectPatient;
  final Function(Patient)? onStartExam;

  const DashboardScreen({
    super.key,
    this.onSelectPatient,
    this.onStartExam,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Patient> _filteredPatients = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _loadDashboardData() {
    setState(() {
      _filteredPatients = PatientRepository.getAllPatients();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredPatients = PatientRepository.searchPatients(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final allPatients = PatientRepository.getAllPatients();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Doctor Greeting & Quick Date Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Good morning, Dr. Sarah Jenkins, MD',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, letterSpacing: -0.5),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: Color(0xFF059669)),
                              SizedBox(width: 4),
                              Text('On Duty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage patient records, review examination history, and create digital prescriptions.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppTheme.primaryBlue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      DateTime.now().toString().substring(0, 10),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Metrics Stat Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: _buildMetricCard(
                    title: 'Total Patients',
                    value: '${allPatients.length}',
                    subtitle: 'Registered records',
                    icon: Icons.people_alt_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 220,
                  child: _buildMetricCard(
                    title: 'Encounters',
                    value: '${allPatients.fold<int>(0, (sum, p) => sum + p.encounters.length)}',
                    subtitle: 'Total recorded',
                    icon: Icons.assignment_turned_in_outlined,
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 220,
                  child: _buildMetricCard(
                    title: 'Prescriptions',
                    value: '4',
                    subtitle: 'Issued today',
                    icon: Icons.local_pharmacy_outlined,
                    color: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 220,
                  child: _buildMetricCard(
                    title: 'Local Vault',
                    value: 'Backed Up',
                    subtitle: 'Encrypted server',
                    icon: Icons.security_outlined,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Prominent Patient Search Bar
          Card(
            color: AppTheme.cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search patient by name, patient ID (MRN), or date of birth...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: AppTheme.primaryBlue, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _onSearchChanged(_searchController.text),
                    icon: const Icon(Icons.person_search_outlined, size: 18),
                    label: const Text('Search Patient'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. Patient Records Grid Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Clinical Patient Records (${_filteredPatients.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const Text(
                'Access clinical history or launch digital eye examination',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _filteredPatients.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No patient records matching your search query.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
                )
              : _buildPatientGrid(),
          const SizedBox(height: 24),

          // 5. Local Clinic Server Data Backup Security Card
          Card(
            color: AppTheme.cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF059669)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Encrypted Local Clinic Server Data Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                        Text('Last Backup: August 18, 2026 — 11:00 PM  •  Status: ✓ Healthy & Synchronized', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: AppTheme.cardBg,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = math.max(1, (constraints.maxWidth / 420).floor());
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _filteredPatients.length,
          itemBuilder: (context, index) {
            final patient = _filteredPatients[index];
            final hasDiagnosis = patient.previousDiagnoses.isNotEmpty;

            return Card(
              color: AppTheme.cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                child: Text(
                                  patient.fullName.substring(0, 1),
                                  style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patient.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${patient.mrn}  •  ${patient.gender}, ${patient.age}y',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${patient.encounters.length} Visits', style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    const Divider(color: AppTheme.borderColor, height: 12),

                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(patient.phone, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const Spacer(),
                        const Icon(Icons.event_outlined, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text('Last: ${patient.lastVisitDate}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(Icons.medical_information_outlined, size: 12, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hasDiagnosis ? patient.previousDiagnoses.first : 'No prior registered conditions',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              if (widget.onSelectPatient != null) {
                                widget.onSelectPatient!(patient);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              side: const BorderSide(color: AppTheme.borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('View History', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (widget.onStartExam != null) {
                                widget.onStartExam!(patient);
                              }
                            },
                            icon: const Icon(Icons.draw, size: 14),
                            label: const Text('New Exam', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
