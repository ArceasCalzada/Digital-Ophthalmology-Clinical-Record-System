import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one page header used by Dashboard, Calendar, Records and Prescriptions
/// (and the Examination app bar, through [titleStyle] and [subtitleStyle]), so
/// every screen opens with the same sizes, spacing and placement.
///
/// [action] sits on the right; below [stackBelow] px it drops under the title
/// and fills the width. The header includes the gap under it, so callers add no
/// spacing of their own.
class PageHeader extends StatelessWidget {
  /// Padding around every page's content, so headers start at the same point.
  static const double pagePadding = 24;

  /// Space between the header and the first thing below it.
  static const double bottomGap = 20;

  // No letter-spacing tweak: tightened letters made titles look like a different
  // font from the rest of the app.
  static const TextStyle titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppTheme.textPrimary,
  );

  static const TextStyle subtitleStyle = TextStyle(fontSize: 14, color: AppTheme.textSecondary);

  final String title;
  final String subtitle;
  final Widget? action;

  /// Width below which [action] moves under the title. Null uses 600.
  final double? stackBelow;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
    this.stackBelow,
  });

  @override
  Widget build(BuildContext context) {
    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 4),
        Text(subtitle, style: subtitleStyle),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final action = this.action;
          if (action == null) return SizedBox(width: double.infinity, child: titles);

          if (constraints.maxWidth < (stackBelow ?? 600)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [titles, const SizedBox(height: 12), action],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titles),
              const SizedBox(width: 16),
              action,
            ],
          );
        },
      ),
    );
  }
}
