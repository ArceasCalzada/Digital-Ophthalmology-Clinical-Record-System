import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one filter pill used across the app (patient quick filters, calendar
/// filters, notification filters), so they all look and behave the same:
/// a light pill with a thin border, filled with [selectedColor] when chosen,
/// and never a check mark.
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color selectedColor;

  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor = AppTheme.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : AppTheme.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: selectedColor,
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(color: selected ? selectedColor : AppTheme.borderColor),
      // Tapping the chosen pill again does nothing: one option is always active.
      onSelected: (isSelected) {
        if (isSelected) onSelected();
      },
    );
  }
}
