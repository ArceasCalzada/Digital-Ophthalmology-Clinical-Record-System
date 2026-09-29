import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'clinical_modal_picker.dart';

/// The app's one selection field: a bordered box that opens its list as a dropdown
/// directly *below* itself (never a pop-up over the page, and no icons in the list).
///
/// Set [searchable] for long lists (e.g. patients): a search box sits at the top of
/// the dropdown. [dense] is the small grey variant used inside the date picker.
///
/// Give it [onAdd] and/or [onRemove] to make the list editable by the user: a footer
/// offers "Add new", and a pencil switches the rows into edit mode, where an X beside
/// each one deletes it after a confirmation.
class ClinicalDropdownField<T> extends StatelessWidget {
  final Widget? label;
  final String placeholder;
  final T? value;
  final List<ClinicalPickerItem<T>> items;
  final ValueChanged<T> onChanged;

  /// Text to show for the chosen value when it should differ from the item's label.
  final String? displayText;
  final bool searchable;
  final String searchHint;

  /// Red outline, for a required field that has been left empty.
  final bool invalid;
  final bool dense;

  /// Adds a new entry by name; returns false when it was refused (empty, duplicate, list full).
  final bool Function(String name)? onAdd;

  /// Deletes an entry. The field asks the user to confirm first.
  final ValueChanged<T>? onRemove;

  /// What the entries are called, used in the footer and the confirmation ("event type").
  final String itemNoun;

  /// Longest name the add box accepts.
  final int maxNameLength;

  const ClinicalDropdownField({
    super.key,
    this.label,
    this.placeholder = 'Select',
    required this.value,
    required this.items,
    required this.onChanged,
    this.displayText,
    this.searchable = false,
    this.searchHint = 'Search...',
    this.invalid = false,
    this.dense = false,
    this.onAdd,
    this.onRemove,
    this.itemNoun = 'item',
    this.maxNameLength = 40,
  });

  String? get _selectedText {
    if (displayText != null && displayText!.isNotEmpty) return displayText;
    for (final item in items) {
      if (item.value == value) return item.label;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedText;
    final height = dense ? 38.0 : 48.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          label!,
          const SizedBox(height: 6),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return MenuAnchor(
              style: MenuStyle(
                backgroundColor: const WidgetStatePropertyAll(Colors.white),
                surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
                elevation: const WidgetStatePropertyAll(6),
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
              alignmentOffset: const Offset(0, 4),
              menuChildren: [
                _DropdownList<T>(
                  width: width,
                  items: items,
                  selected: value,
                  searchable: searchable,
                  searchHint: searchHint,
                  onPick: onChanged,
                  onAdd: onAdd,
                  onRemove: onRemove,
                  itemNoun: itemNoun,
                  maxNameLength: maxNameLength,
                ),
              ],
              builder: (context, controller, child) {
                return InkWell(
                  borderRadius: BorderRadius.circular(dense ? 8 : 10),
                  onTap: () => controller.isOpen ? controller.close() : controller.open(),
                  child: Container(
                    height: height,
                    padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14),
                    decoration: BoxDecoration(
                      color: dense ? AppTheme.lightBg : Colors.white,
                      borderRadius: BorderRadius.circular(dense ? 8 : 10),
                      border: Border.all(
                        color: invalid
                            ? const Color(0xFFDC2626)
                            : (dense ? AppTheme.borderColor : const Color(0xFFCBD5E1)),
                        width: invalid ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selected ?? placeholder,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected != null ? (dense ? FontWeight.w600 : FontWeight.bold) : FontWeight.normal,
                              color: selected != null ? AppTheme.textPrimary : const Color(0xFF94A3B8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryBlue, size: 20),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// The list inside the dropdown. It is created when the menu opens, so it starts
/// scrolled with the chosen entry in view, and (when searchable) with a fresh search box.
class _DropdownList<T> extends StatefulWidget {
  final double width;
  final List<ClinicalPickerItem<T>> items;
  final T? selected;
  final bool searchable;
  final String searchHint;
  final ValueChanged<T> onPick;
  final bool Function(String name)? onAdd;
  final ValueChanged<T>? onRemove;
  final String itemNoun;
  final int maxNameLength;

  const _DropdownList({
    required this.width,
    required this.items,
    required this.selected,
    required this.searchable,
    required this.searchHint,
    required this.onPick,
    required this.onAdd,
    required this.onRemove,
    required this.itemNoun,
    required this.maxNameLength,
  });

  @override
  State<_DropdownList<T>> createState() => _DropdownListState<T>();
}

class _DropdownListState<T> extends State<_DropdownList<T>> {
  static const double _rowHeight = 40;
  static const double _rowHeightWithSubtitle = 52;
  static const double _maxListHeight = 280;

  final _search = TextEditingController();
  final _newName = TextEditingController();
  late final ScrollController _scroll;
  String _query = '';
  bool _editing = false; // X buttons shown beside each row
  bool _adding = false; // the "new name" box is open
  bool _addRefused = false; // the last name typed was refused for a reason other than being a duplicate
  T? _flashValue; // the existing entry to highlight because the name typed is a duplicate of it
  int _flashCount = 0; // bumps on every duplicate so the highlight restarts each time

  double _rowHeightOf(ClinicalPickerItem<T> item) => item.subtitle == null ? _rowHeight : _rowHeightWithSubtitle;

  @override
  void initState() {
    super.initState();
    // Start with the chosen row roughly centred (rows are a fixed height per kind).
    var offset = 0.0;
    for (final item in widget.items) {
      if (item.value == widget.selected) break;
      offset += _rowHeightOf(item);
    }
    final listHeight = _listHeight(widget.items);
    final total = widget.items.fold<double>(0, (sum, item) => sum + _rowHeightOf(item));
    _scroll = ScrollController(
      initialScrollOffset: (offset - listHeight / 2 + _rowHeight / 2).clamp(0, (total - listHeight).clamp(0, double.infinity)).toDouble(),
    );
  }

  double _listHeight(List<ClinicalPickerItem<T>> shown) {
    final total = shown.fold<double>(0, (sum, item) => sum + _rowHeightOf(item));
    return total.clamp(_rowHeight, _maxListHeight).toDouble();
  }

  @override
  void dispose() {
    _search.dispose();
    _newName.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The entry that already has this name (ignoring case and extra spaces), if any.
  ClinicalPickerItem<T>? _existing(String name) {
    String tidy(String v) => v.trim().replaceAll(RegExp(r's+'), ' ').toLowerCase();
    final wanted = tidy(name);
    if (wanted.isEmpty) return null;
    for (final item in widget.items) {
      if (tidy(item.label) == wanted) return item;
    }
    return null;
  }

  void _submitNew() {
    final duplicate = _existing(_newName.text);
    final accepted = widget.onAdd?.call(_newName.text) ?? false;
    setState(() {
      _addRefused = !accepted && duplicate == null;
      if (accepted) {
        _newName.clear();
        _adding = false;
      } else if (duplicate != null) {
        // Show which one it is: it lights up and fades, and the list scrolls to it.
        _flashValue = duplicate.value;
        _flashCount++;
      }
    });
    if (duplicate != null && !accepted) _scrollTo(duplicate);
  }

  void _scrollTo(ClinicalPickerItem<T> item) {
    if (!_scroll.hasClients) return;
    var offset = 0.0;
    for (final i in widget.items) {
      if (i.value == item.value) break;
      offset += _rowHeightOf(i);
    }
    final target = (offset - 40).clamp(0, _scroll.position.maxScrollExtent).toDouble();
    _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _confirmRemove(ClinicalPickerItem<T> item) async {
    // The menu may close while the dialog is up (a tap on the dialog is outside the menu),
    // so keep what is needed rather than reading it from this state afterwards.
    final onRemove = widget.onRemove;
    final noun = widget.itemNoun;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $noun?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Text(
          '"${item.label}" will be removed from the list. Events that already use it keep it.',
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) onRemove?.call(item.value);
  }

  Widget _buildFooter() {
    final canEdit = widget.onRemove != null;
    // Snug padding so "+ Add new" and "Done" both fit in a half-width dropdown without an ellipsis.
    final footerButton = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.borderColor))),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      height: 46,
      child: _adding
          ? Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextField(
                      controller: _newName,
                      autofocus: true,
                      maxLength: widget.maxNameLength,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      onChanged: (_) {
                        if (_addRefused) setState(() => _addRefused = false);
                      },
                      onSubmitted: (_) => _submitNew(),
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'New ${widget.itemNoun} name',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        enabledBorder: _addRefused
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add',
                  icon: const Icon(Icons.check_rounded, size: 20, color: AppTheme.primaryBlue),
                  onPressed: _submitNew,
                ),
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                  onPressed: () => setState(() {
                    _adding = false;
                    _addRefused = false;
                    _newName.clear();
                  }),
                ),
              ],
            )
          : Row(
              children: [
                // Takes all the room the pencil / Done leaves, so it is never squeezed to "+ Add n...".
                Expanded(
                  child: widget.onAdd == null
                      ? const SizedBox()
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() {
                              _adding = true;
                              _editing = false;
                            }),
                            style: footerButton,
                            child: const Text('+ Add new', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600), softWrap: false),
                          ),
                        ),
                ),
                if (canEdit)
                  _editing
                      ? TextButton(
                          onPressed: () => setState(() => _editing = false),
                          style: footerButton,
                          child: const Text('Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        )
                      : IconButton(
                          tooltip: 'Edit list',
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                          onPressed: () => setState(() => _editing = true),
                        ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.items
        : widget.items.where((i) => i.label.toLowerCase().contains(q) || (i.subtitle ?? '').toLowerCase().contains(q)).toList();

    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No matches', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            )
          else
            SizedBox(
              height: _listHeight(shown),
              child: ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.zero,
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final item = shown[index];
                  final isSelected = item.value == widget.selected;
                  return SizedBox(
                    height: _rowHeightOf(item),
                    child: InkWell(
                      onTap: item.enabled && !_editing
                          ? () {
                              widget.onPick(item.value);
                              MenuController.maybeOf(context)?.close();
                            }
                          : null,
                      child: _FadingHighlight(
                        // A new key each time restarts the fade.
                        key: item.value == _flashValue ? ValueKey(_flashCount) : null,
                        active: item.value == _flashValue && _flashCount > 0,
                        base: isSelected ? const Color(0xFFE2E8F0) : null,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: item.enabled ? AppTheme.textPrimary : Colors.grey.shade400,
                                    ),
                                  ),
                                  if (item.subtitle != null)
                                    Text(
                                      item.subtitle!,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            if (_editing && item.removable)
                              IconButton(
                                tooltip: 'Delete ${item.label}',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC2626)),
                                onPressed: () => _confirmRemove(item),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (widget.onAdd != null || widget.onRemove != null) _buildFooter(),
        ],
      ),
    );
  }
}

/// A row background that flashes a highlight and fades back to [base] (used to point
/// out the entry a duplicate name matches). Static when not [active].
class _FadingHighlight extends StatelessWidget {
  final bool active;
  final Color? base;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _FadingHighlight({super.key, required this.active, required this.base, required this.padding, required this.child});

  Widget _row(Color? color) => Container(color: color ?? Colors.transparent, padding: padding, alignment: Alignment.centerLeft, child: child);

  @override
  Widget build(BuildContext context) {
    if (!active) return _row(base);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeIn,
      builder: (context, t, _) => _row(Color.alphaBlend(AppTheme.primaryBlue.withValues(alpha: 0.28 * t), base ?? Colors.transparent)),
    );
  }
}
