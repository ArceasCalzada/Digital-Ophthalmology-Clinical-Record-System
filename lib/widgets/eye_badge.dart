import 'package:flutter/material.dart';
import '../models/eye_exam.dart';
import '../theme/app_theme.dart';

class EyeBadge extends StatelessWidget {
    final EyeType eye;

    const EyeBadge ({super.key, required this.eye});

    @override
    Widget build(BuildContext context){
        final color = eye == EyeType.OD ? AppTheme.odColor : AppTheme.osColor;
        final label = eye == EyeType.OD ? 'OD (Right Eye)' : 'OS (Left Eye)';

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 1.5),
                borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
                label, 
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                ),
            ),
        );
    }
}