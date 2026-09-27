import 'package:flutter/foundation.dart';

class LocalDraft {
  final String contextKey; // 'eye_exam', 'prescription', 'new_patient'
  final String? patientId;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;
  final int ttlHours;

  LocalDraft({
    required this.contextKey,
    this.patientId,
    required this.payload,
    required this.updatedAt,
    this.ttlHours = 24,
  });

  bool get isExpired {
    final expiryTime = updatedAt.add(Duration(hours: ttlHours));
    return DateTime.now().isAfter(expiryTime);
  }

  Map<String, dynamic> toJson() => {
        'contextKey': contextKey,
        'patientId': patientId,
        'payload': payload,
        'updatedAt': updatedAt.toIso8601String(),
        'ttlHours': ttlHours,
      };

  factory LocalDraft.fromJson(Map<String, dynamic> json) => LocalDraft(
        contextKey: json['contextKey'] ?? '',
        patientId: json['patientId'],
        payload: Map<String, dynamic>.from(json['payload'] ?? {}),
        updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
        ttlHours: json['ttlHours'] ?? 24,
      );
}

class DraftManagerService extends ChangeNotifier {
  static final DraftManagerService _instance = DraftManagerService._internal();
  factory DraftManagerService() => _instance;

  final Map<String, LocalDraft> _drafts = {};

  DraftManagerService._internal();

  /// Saves or overwrites the single active draft for a specific context.
  void saveDraft({
    required String contextKey,
    required Map<String, dynamic> payload,
    String? patientId,
    int ttlHours = 24,
  }) {
    final draft = LocalDraft(
      contextKey: contextKey,
      patientId: patientId,
      payload: payload,
      updatedAt: DateTime.now(),
      ttlHours: ttlHours,
    );

    _drafts[contextKey] = draft;
    notifyListeners();
  }

  /// Checks for a valid draft. Automatically purges if expired (TTL exceeded).
  LocalDraft? getValidDraft(String contextKey) {
    final draft = _drafts[contextKey];
    if (draft == null) return null;

    if (draft.isExpired) {
      debugPrint('Draft for context "$contextKey" exceeded TTL (${draft.ttlHours}h). Automatically purging.');
      _drafts.remove(contextKey);
      notifyListeners();
      return null;
    }

    return draft;
  }

  /// Checks if a valid, unexpired draft exists for a context.
  bool hasValidDraft(String contextKey) {
    return getValidDraft(contextKey) != null;
  }

  /// Discards/purges the draft for a specific context.
  void discardDraft(String contextKey) {
    if (_drafts.containsKey(contextKey)) {
      _drafts.remove(contextKey);
      notifyListeners();
    }
  }

  /// Clears all local drafts (useful for testing/resetting).
  void clearAllDrafts() {
    _drafts.clear();
    notifyListeners();
  }
}
