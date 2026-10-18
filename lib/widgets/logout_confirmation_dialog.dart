import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Displays a confirmation dialog before signing out of the workstation.
/// Returns `true` if the user confirmed logout, or `false` if cancelled.
Future<bool> showLogoutConfirmationDialog(
  BuildContext context, {
  String title = 'Confirm Logout',
  String message = 'Are you sure you want to log out? You will need to sign in again to access patient records and clinical workspaces.',
  String cancelButtonText = 'Cancel',
  String confirmButtonText = 'Confirm Logout',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => LogoutConfirmationDialog(
      title: title,
      message: message,
      cancelButtonText: cancelButtonText,
      confirmButtonText: confirmButtonText,
    ),
  );
  return confirmed ?? false;
}

class LogoutConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelButtonText;
  final String confirmButtonText;

  const LogoutConfirmationDialog({
    super.key,
    this.title = 'Confirm Logout',
    this.message = 'Are you sure you want to log out? You will need to sign in again to access patient records and clinical workspaces.',
    this.cancelButtonText = 'Cancel',
    this.confirmButtonText = 'Confirm Logout',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppTheme.cardBg,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFE11D48),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to log out?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('cancel_logout_button'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelButtonText,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          key: const ValueKey('confirm_logout_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE11D48),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmButtonText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
