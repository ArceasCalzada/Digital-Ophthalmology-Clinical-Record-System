import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Item representation for modal pickers.
class ClinicalPickerItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  const ClinicalPickerItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
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

  const ClinicalActionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// Opens a modal bottom sheet (or centered dialog on desktop) for selecting an item from a list.
Future<T?> showClinicalModalPicker<T>({
  required BuildContext context,
  required String title,
  required List<ClinicalPickerItem<T>> items,
  T? selectedValue,
  String? searchHint,
  bool enableSearch = false,
}) async {
  final isMobile = MediaQuery.of(context).size.width < 600;

  Widget content = _ClinicalModalPickerContent<T>(
    title: title,
    items: items,
    selectedValue: selectedValue,
    searchHint: searchHint,
    enableSearch: enableSearch,
  );

  if (isMobile) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => content,
    );
  } else {
    return showDialog<T>(
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

class _ClinicalModalPickerContent<T> extends StatefulWidget {
  final String title;
  final List<ClinicalPickerItem<T>> items;
  final T? selectedValue;
  final String? searchHint;
  final bool enableSearch;

  const _ClinicalModalPickerContent({
    required this.title,
    required this.items,
    this.selectedValue,
    this.searchHint,
    this.enableSearch = false,
  });

  @override
  State<_ClinicalModalPickerContent<T>> createState() => _ClinicalModalPickerContentState<T>();
}

class _ClinicalModalPickerContentState<T> extends State<_ClinicalModalPickerContent<T>> {
  late List<ClinicalPickerItem<T>> _filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final labelMatch = item.label.toLowerCase().contains(q);
          final subMatch = item.subtitle?.toLowerCase().contains(q) ?? false;
          return labelMatch || subMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxH = mediaQuery.size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill for mobile
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Search Field if enabled
          if (widget.enableSearch) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: widget.searchHint ?? 'Search options...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                ),
              ),
            ),
          ],

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // List of Items
          Flexible(
            child: _filteredItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No options match your search', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = item.value == widget.selectedValue;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, item.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                if (item.icon != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (item.iconColor ?? AppTheme.primaryBlue).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(item.icon, color: item.iconColor ?? AppTheme.primaryBlue, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                                        ),
                                      ),
                                      if (item.subtitle != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.subtitle!,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: mediaQuery.padding.bottom + 12),
        ],
      ),
    );
  }
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
    padding: const EdgeInsets.only(top: 12, bottom: 20, left: 20, right: 20),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle pill
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF64748B)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...actions.map((act) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    act.onTap();
                  },
                  borderRadius: BorderRadius.circular(14),
                  hoverColor: act.color.withValues(alpha: 0.08),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: act.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(act.icon, color: act.color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                act.title,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                act.subtitle,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
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

/// A form field component that displays a selected value and opens a Modal Picker on tap.
class ClinicalModalPickerField<T> extends StatelessWidget {
  final String? label;
  final String placeholder;
  final String displayText;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isHighlighted;

  const ClinicalModalPickerField({
    super.key,
    this.label,
    required this.placeholder,
    required this.displayText,
    this.icon,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = displayText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
        ],
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHighlighted ? AppTheme.primaryBlue : const Color(0xFFCBD5E1),
                width: isHighlighted ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: isHighlighted ? AppTheme.primaryBlue : const Color(0xFF64748B)),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    hasValue ? displayText : placeholder,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                      color: hasValue ? AppTheme.textPrimary : const Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryBlue, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
