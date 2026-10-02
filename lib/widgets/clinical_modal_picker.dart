import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// One choice in a dropdown (see ClinicalDropdownField).
class ClinicalPickerItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  /// False greys the entry out and makes it unselectable.
  final bool enabled;

  /// Whether the entry can be deleted when the dropdown is editable (e.g. "None" cannot).
  final bool removable;

  ClinicalPickerItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.enabled = true,
    this.removable = true,
  });
}

/// Action item representation for action selection modals.
class ClinicalActionItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  ClinicalActionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// Displays an action selector modal sheet / dialog.
Future<void> showClinicalActionModal({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<ClinicalActionItem> actions,
}) async {
  final isMobile = MediaQuery.of(context).size.width < 600;

  Widget content = Container(
    padding: EdgeInsets.only(top: 20, bottom: 20, left: 20, right: 20),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Color(0xFF64748B)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        SizedBox(height: 16),
        ...actions.map((act) => Container(
              margin: EdgeInsets.only(bottom: 10),
              child: Material(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    act.onTap();
                  },
                  borderRadius: BorderRadius.circular(14),
                  hoverColor: act.color.withValues(alpha: 0.08),
                  child: Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: act.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(act.icon, color: act.color, size: 22),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                act.title,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                act.subtitle,
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    ),
  );

  if (isMobile) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => content,
    );
  } else {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 440,
          child: content,
        ),
      ),
    );
  }
}
