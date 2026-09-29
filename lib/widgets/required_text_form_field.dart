import 'package:flutter/material.dart';

import 'shake_widget.dart';

/// A text field for a required value. When the form is submitted with it empty the
/// field shakes and turns red instead of printing "Required" underneath.
///
/// [invalidMessage] is for a value that is filled in but wrong (e.g. an unreadable
/// date). Its message is shown under the field, and the field shakes too.
class RequiredTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final bool obscureText;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  /// Whether surrounding spaces are ignored when deciding if the field is empty.
  final bool trim;

  final String? Function(String value)? invalidMessage;

  const RequiredTextFormField({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.style,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.trim = true,
    this.invalidMessage,
  });

  @override
  State<RequiredTextFormField> createState() => _RequiredTextFormFieldState();
}

class _RequiredTextFormFieldState extends State<RequiredTextFormField> {
  final _shake = GlobalKey<ShakeWidgetState>();

  /// Set while the value is filled in but wrong, so its message is shown.
  bool _showMessage = false;

  String? _validate(String? raw) {
    final value = widget.trim ? (raw ?? '').trim() : (raw ?? '');
    if (value.isEmpty) {
      _remember(false);
      _shake.currentState?.shake();
      return ''; // an empty message still puts the field in its red error state
    }
    final message = widget.invalidMessage?.call(value);
    if (message != null) {
      _remember(true);
      _shake.currentState?.shake();
      return message;
    }
    _remember(false);
    return null;
  }

  void _remember(bool show) {
    if (show != _showMessage) setState(() => _showMessage = show);
  }

  @override
  Widget build(BuildContext context) {
    return ShakeWidget(
      key: _shake,
      child: TextFormField(
        controller: widget.controller,
        style: widget.style,
        obscureText: widget.obscureText,
        maxLines: widget.maxLines,
        onChanged: widget.onChanged,
        decoration: widget.decoration.copyWith(
          // Nothing is printed for "empty"; only a real message takes up room.
          errorStyle: _showMessage ? null : const TextStyle(fontSize: 0, height: 0),
        ),
        validator: _validate,
      ),
    );
  }
}
