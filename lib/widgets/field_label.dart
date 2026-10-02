import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Label above a form field. Required fields get a red asterisk, so every form
/// marks "must fill in" the same way.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final double fontSize;

  const FieldLabel(this.text, {super.key, this.required = false, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required) TextSpan(text: ' *', style: TextStyle(color: Color(0xFFDC2626))),
        ],
      ),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }
}
