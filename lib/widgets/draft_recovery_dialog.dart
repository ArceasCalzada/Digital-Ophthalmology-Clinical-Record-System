import 'package:flutter/material.dart';
import '../services/draft_manager_service.dart';
import '../theme/app_theme.dart';

class DraftRecoveryDialog extends StatelessWidget {
  final LocalDraft draft;
  final Function(Map<String, dynamic> payload) onResume;
  final VoidCallback onDiscard;

  const DraftRecoveryDialog({
    super.key,
    required this.draft,
    required this.onResume,
    required this.onDiscard,
  });

  static Future<void> checkAndShow(
    BuildContext context, {
    required String contextKey,
    required Function(Map<String, dynamic> payload) onResume,
    required VoidCallback onDiscard,
  }) async {
    final draftService = DraftManagerService();
    final validDraft = draftService.getValidDraft(contextKey);

    if (validDraft == null) {
      onDiscard();
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DraftRecoveryDialog(
        draft: validDraft,
        onResume: (payload) {
          Navigator.pop(ctx);
          onResume(payload);
        },
        onDiscard: () {
          draftService.discardDraft(contextKey);
          Navigator.pop(ctx);
          onDiscard();
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  String _getContextTitle(String contextKey) {
    switch (contextKey) {
      case 'eye_exam':
        return 'Unsaved Ocular Examination Draft';
      case 'prescription':
        return 'Unsaved Prescription Draft';
      case 'new_patient':
        return 'Unsaved Patient Registration Draft';
      default:
        return 'Unsaved Form Draft Discovered';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _getContextTitle(draft.contextKey);
    final timeAgo = _formatTimeAgo(draft.updatedAt);
    final patientName = draft.payload['patientName'] ?? draft.payload['fullName'] ?? 'Active Patient';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFFD97706).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.restore_page_rounded, color: Color(0xFFD97706), size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Patient / Context:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    Text(
                      '$patientName',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Auto-Saved:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          Text(
            'An uncompleted draft was automatically saved locally from your previous session.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
          ),
          SizedBox(height: 6),
          Text(
            'Note: Drafts are strictly local to this device and are never synced to the cloud.',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
          ),
        ],
      ),
      actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        OutlinedButton.icon(
          onPressed: onDiscard,
          icon: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
          label: Text('Discard & Start New', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Color(0xFFFECACA)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => onResume(draft.payload),
          icon: Icon(Icons.play_arrow_rounded, size: 18),
          label: Text('Resume Draft', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
