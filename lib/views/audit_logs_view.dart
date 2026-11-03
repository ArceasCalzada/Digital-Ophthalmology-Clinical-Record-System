import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/audit_log.dart';
import '../models/team.dart';
import '../services/audit_service.dart';
import '../services/team_service.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_pill.dart';
import '../widgets/page_header.dart';

/// Secure, immutable Audit Trail & Activity Logging View.
/// Accessible strictly to users with the Owner role or Master Admin.
class AuditLogsView extends StatefulWidget {
  final bool isEmbedded;

  const AuditLogsView({super.key, this.isEmbedded = false});

  @override
  State<AuditLogsView> createState() => _AuditLogsViewState();
}

class _AuditLogsViewState extends State<AuditLogsView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedStaff = 'All Staff';
  String _selectedDatePreset = 'All Time';
  DateTimeRange? _customDateRange;

  int _currentPage = 1;
  int _pageSize = 15;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _canAccess {
    return TeamService.instance.isMasterAdmin ||
        TeamService.instance.activeRole == TeamRole.owner;
  }

  DateTimeRange? _resolveEffectiveDateRange() {
    final now = DateTime.now();
    switch (_selectedDatePreset) {
      case 'Today':
        final today = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: today, end: today);
      case 'Last 7 Days':
        return DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
      case 'Last 30 Days':
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
      case 'Custom':
        return _customDateRange;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canAccess) {
      return _buildAccessRestrictedView(context);
    }

    final activeTeam = TeamService.instance.activeTeam;
    final activeTeamId = activeTeam?.id ?? 'c-default-team';

    final content = StreamBuilder<List<AuditLog>>(
      stream: AuditService.instance.streamAuditLogs(teamId: activeTeamId, limit: 300),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final rawLogs = snapshot.data ?? [];

        // Build list of unique staff emails for filter dropdown
        final staffList = <String>{'All Staff'};
        for (final l in rawLogs) {
          if (l.userEmail.isNotEmpty) {
            staffList.add(l.userEmail);
          }
        }

        // Apply filters
        final effectiveRange = _resolveEffectiveDateRange();
        final filtered = rawLogs.where((log) {
          // 1. Category
          if (_selectedCategory != 'All' && log.actionCategory != _selectedCategory) {
            return false;
          }

          // 2. Staff
          if (_selectedStaff != 'All Staff' &&
              log.userEmail.toLowerCase() != _selectedStaff.toLowerCase()) {
            return false;
          }

          // 3. Date Range
          if (effectiveRange != null) {
            final start = DateTime(
              effectiveRange.start.year,
              effectiveRange.start.month,
              effectiveRange.start.day,
            );
            final end = DateTime(
              effectiveRange.end.year,
              effectiveRange.end.month,
              effectiveRange.end.day,
              23,
              59,
              59,
            );
            if (log.timestamp.isBefore(start) || log.timestamp.isAfter(end)) {
              return false;
            }
          }

          // 4. Search query
          final q = _searchController.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            final matches = log.userName.toLowerCase().contains(q) ||
                log.userEmail.toLowerCase().contains(q) ||
                log.resourceName.toLowerCase().contains(q) ||
                log.resourceId.toLowerCase().contains(q) ||
                log.details.toLowerCase().contains(q) ||
                log.actionLabel.toLowerCase().contains(q);
            if (!matches) return false;
          }

          return true;
        }).toList();

        // Pagination
        final totalItems = filtered.length;
        final totalPages = (totalItems / _pageSize).ceil().clamp(1, 9999);
        if (_currentPage > totalPages) _currentPage = totalPages;
        final startIndex = (_currentPage - 1) * _pageSize;
        final endIndex = (startIndex + _pageSize).clamp(0, totalItems);
        final paginatedLogs = (startIndex < totalItems)
            ? filtered.sublist(startIndex, endIndex)
            : <AuditLog>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildComplianceBanner(context, activeTeam?.name ?? 'Primary Clinic'),
            const SizedBox(height: 16),
            _buildFiltersCard(context, staffList.toList()),
            const SizedBox(height: 16),
            _buildLogsCard(context, paginatedLogs, totalItems, totalPages),
          ],
        );
      },
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PageHeader.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Clinic Audit Trail & Activity Logs',
              subtitle:
                  'Immutable log of staff modifications, prescription prints, member approvals, and branch archiving.',
              action: _buildHeaderActions(context),
            ),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const Key('btn_refresh_audit_logs'),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
          onPressed: () => setState(() {}),
        ),
        ElevatedButton.icon(
          key: const Key('btn_export_audit_logs'),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Export CSV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _exportLogsAsCsv(context),
        ),
      ],
    );
  }

  Widget _buildComplianceBanner(BuildContext context, String teamName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_rounded, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SECURE MEDICAL AUDIT TRAIL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'IMMUTABLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Workspace: $teamName • Records are append-only and cannot be modified or deleted in compliance with clinical record regulations.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard(BuildContext context, List<String> staffList) {
    return Card(
      color: AppTheme.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            TextField(
              key: const Key('audit_search_input'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by staff email, patient name, MRN, resource ID, or action...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.lightBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.borderColor),
                ),
              ),
              onChanged: (_) => setState(() => _currentPage = 1),
            ),
            const SizedBox(height: 14),

            // Category Filter Pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Category:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                FilterPill(
                  label: 'All Categories',
                  selected: _selectedCategory == 'All',
                  onSelected: () => setState(() {
                    _selectedCategory = 'All';
                    _currentPage = 1;
                  }),
                ),
                ...AuditActionCategory.all.map((cat) {
                  return FilterPill(
                    label: cat,
                    selected: _selectedCategory == cat,
                    onSelected: () => setState(() {
                      _selectedCategory = cat;
                      _currentPage = 1;
                    }),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),

            // Dropdowns for Staff Member & Date Preset
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Staff Member Filter
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Staff:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('dropdown_staff_filter'),
                          value: staffList.contains(_selectedStaff) ? _selectedStaff : 'All Staff',
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                          items: staffList.map((email) {
                            return DropdownMenuItem<String>(
                              value: email,
                              child: Text(email),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedStaff = val;
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Date Range Filter
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Date:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('dropdown_date_filter'),
                          value: _selectedDatePreset,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                          items: const [
                            DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                            DropdownMenuItem(value: 'Today', child: Text('Today')),
                            DropdownMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
                            DropdownMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days')),
                            DropdownMenuItem(value: 'Custom', child: Text('Custom Range...')),
                          ],
                          onChanged: (val) async {
                            if (val == null) return;
                            if (val == 'Custom') {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDatePreset = 'Custom';
                                  _customDateRange = picked;
                                  _currentPage = 1;
                                });
                              }
                            } else {
                              setState(() {
                                _selectedDatePreset = val;
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Reset Filters Button
                if (_selectedCategory != 'All' ||
                    _selectedStaff != 'All Staff' ||
                    _selectedDatePreset != 'All Time' ||
                    _searchController.text.isNotEmpty)
                  TextButton.icon(
                    key: const Key('btn_clear_audit_filters'),
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Reset Filters'),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _selectedCategory = 'All';
                        _selectedStaff = 'All Staff';
                        _selectedDatePreset = 'All Time';
                        _customDateRange = null;
                        _currentPage = 1;
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsCard(
    BuildContext context,
    List<AuditLog> logs,
    int totalItems,
    int totalPages,
  ) {
    return Card(
      color: AppTheme.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Audit Records',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$totalItems Total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Page $_currentPage of $totalPages',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const Divider(height: 24),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'No audit events found matching your criteria.',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemBuilder: (context, idx) {
                  final log = logs[idx];
                  return _buildAuditLogTile(context, log);
                },
              ),
            const SizedBox(height: 16),

            // Pagination Controls
            if (totalItems > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Rows per page: ',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _pageSize,
                          items: const [
                            DropdownMenuItem(value: 10, child: Text('10')),
                            DropdownMenuItem(value: 15, child: Text('15')),
                            DropdownMenuItem(value: 25, child: Text('25')),
                            DropdownMenuItem(value: 50, child: Text('50')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _pageSize = val;
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        key: const Key('btn_audit_prev_page'),
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: _currentPage > 1
                            ? () => setState(() => _currentPage--)
                            : null,
                      ),
                      Text(
                        '$_currentPage / $totalPages',
                        style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        key: const Key('btn_audit_next_page'),
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: _currentPage < totalPages
                            ? () => setState(() => _currentPage++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogTile(BuildContext context, AuditLog log) {
    final catColor = log.categoryColor;

    return InkWell(
      onTap: () => _showLogDetailsDialog(context, log),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action Icon badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(log.actionIcon, color: catColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Action Type badge & category
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log.actionLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                              ),
                            ),
                          ),
                          Text(
                            '• ${log.actionCategory}',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),

                      // Timestamp
                      Text(
                        log.relativeTime,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Details summary
                  Text(
                    log.details.isNotEmpty ? log.details : 'No additional details provided.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Staff & Resource metadata
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${log.userName} (${log.userEmail})',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.borderColor.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.userRole.toUpperCase(),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ),
                      if (log.resourceId.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link_rounded, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${log.resourceType}: ${log.resourceId}',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogDetailsDialog(BuildContext context, AuditLog log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(log.actionIcon, color: log.categoryColor, size: 22),
            const SizedBox(width: 10),
            Text(log.actionLabel),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModalDetailRow('Timestamp', log.formattedTimestamp),
                _buildModalDetailRow('Action Type', log.actionType),
                _buildModalDetailRow('Category', log.actionCategory),
                _buildModalDetailRow('Staff Member', '${log.userName} (${log.userEmail})'),
                _buildModalDetailRow('Staff Role', log.userRole),
                _buildModalDetailRow('User UID', log.userId),
                _buildModalDetailRow('Resource Type', log.resourceType),
                _buildModalDetailRow('Resource ID', log.resourceId),
                if (log.resourceName.isNotEmpty)
                  _buildModalDetailRow('Resource Name', log.resourceName),
                _buildModalDetailRow('Details', log.details),
                _buildModalDetailRow('Log ID', log.id),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log.toJson().toString()));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied audit log JSON to clipboard')),
              );
            },
            child: const Text('Copy JSON'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildModalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _exportLogsAsCsv(BuildContext context) {
    final logs = AuditService.instance.memoryLogs;
    final buffer = StringBuffer();
    buffer.writeln('LogID,Timestamp,StaffName,StaffEmail,StaffRole,ActionType,Category,ResourceType,ResourceID,Details');
    for (final l in logs) {
      final safeDetails = l.details.replaceAll('"', '""');
      buffer.writeln(
        '"${l.id}","${l.timestamp.toIso8601String()}","${l.userName}","${l.userEmail}","${l.userRole}","${l.actionType}","${l.actionCategory}","${l.resourceType}","${l.resourceId}","$safeDetails"',
      );
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${logs.length} audit logs. CSV data copied to clipboard.'),
      ),
    );
  }

  Widget _buildAccessRestrictedView(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Card(
        color: AppTheme.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.gpp_bad_rounded, color: Color(0xFFDC2626), size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Audit Logs Restricted',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Access to the clinical audit trail is strictly restricted to the Clinic Owner role.\nMedical compliance records are confidential and tamper-evident.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.lightBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text(
                  'Your Current Role: ${TeamService.instance.activeRole.label}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
