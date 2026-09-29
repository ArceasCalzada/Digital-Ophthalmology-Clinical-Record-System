import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'firebase_gate.dart';

enum NetworkConnectivityState { online, offline }

enum SyncStatusState { upToDate, syncing, offlineSaved, error }

/// One Firestore write inside a [SyncMutation].
class SyncOp {
  /// Full document path, e.g. `patients/pat-1` or `meta/counters`.
  final String path;

  /// `set` (merge), `delete`, or `increment` (data = {field: delta}).
  final String kind;
  final Map<String, dynamic> data;

  const SyncOp.set(this.path, this.data) : kind = 'set';
  const SyncOp.delete(this.path)
      : kind = 'delete',
        data = const {};
  const SyncOp.increment(this.path, this.data) : kind = 'increment';
}

class SyncMutation {
  final String id;
  final String entityType; // 'Patient', 'Encounter', 'CalendarEvent', 'Prescription', 'Notification'
  final String action; // 'CREATE', 'UPDATE', 'DELETE'
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  /// Explicit writes for this mutation. All ops commit atomically in one batch.
  /// When null, ops are derived from [entityType] / [action] / [payload].
  final List<SyncOp>? ops;

  /// True once the batch has been handed to Firestore. A submitted mutation is
  /// never submitted again — Firestore itself keeps it durable until the server
  /// acknowledges it, and re-submitting would double-count counters.
  bool submitted = false;

  /// Why the server rejected this mutation, if it did.
  String? error;

  /// Called when the server rejects this mutation, so the app can undo the
  /// optimistic local change instead of showing data that was never saved.
  final void Function(String reason)? onRejected;

  SyncMutation({
    required this.id,
    required this.entityType,
    required this.action,
    required this.payload,
    required this.timestamp,
    this.ops,
    this.onRejected,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType,
        'action': action,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Ops to write. Encounters and prescriptions live under their patient, so
  /// those must be supplied explicitly (or carry a `patientId` in the payload).
  List<SyncOp> resolveOps() {
    if (ops != null) return ops!;
    final String? path = switch (entityType) {
      'Patient' => 'patients/$id',
      'CalendarEvent' => 'calendarEvents/$id',
      'Notification' => 'notifications/$id',
      'Encounter' when payload['patientId'] is String => 'patients/${payload['patientId']}/encounters/$id',
      'Prescription' when payload['patientId'] is String => 'patients/${payload['patientId']}/prescriptions/$id',
      _ => null,
    };
    if (path == null) {
      throw StateError('No Firestore path for $entityType "$id".');
    }
    return [
      if (action == 'DELETE') SyncOp.delete(path) else SyncOp.set(path, payload),
    ];
  }
}

class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;

  /// How long [syncNow] waits for server acknowledgement before reporting the
  /// data as "saved on this device, waiting for network".
  static const Duration ackWait = Duration(seconds: 8);

  NetworkConnectivityState _networkState = NetworkConnectivityState.online;
  SyncStatusState _syncState = SyncStatusState.upToDate;
  DateTime? _lastSyncedAt = DateTime.now();

  final List<SyncMutation> _pendingQueue = [];
  final List<SyncMutation> _failed = [];
  Timer? _autoSyncTimer;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  OfflineSyncService._internal();

  NetworkConnectivityState get networkState => _networkState;
  SyncStatusState get syncState => _syncState;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  List<SyncMutation> get pendingQueue => List.unmodifiable(_pendingQueue);
  int get pendingCount => _pendingQueue.length;

  /// Mutations the server refused (for example rules or size limits). They are
  /// kept so nothing is silently lost; call [retryFailed] or [discardFailed].
  List<SyncMutation> get failedMutations => List.unmodifiable(_failed);
  String? get lastError => _failed.isEmpty ? null : _failed.last.error;

  bool get isOnline => _networkState == NetworkConnectivityState.online;
  bool get isOffline => _networkState == NetworkConnectivityState.offline;

  void startAutoSyncTimer({Duration interval = const Duration(seconds: 15)}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (_) {
      if (isOnline && _pendingQueue.any((m) => !m.submitted) && _syncState != SyncStatusState.syncing) {
        syncNow();
      }
    });
  }

  void toggleNetworkState() {
    if (_networkState == NetworkConnectivityState.online) {
      setNetworkState(NetworkConnectivityState.offline);
    } else {
      setNetworkState(NetworkConnectivityState.online);
    }
  }

  void setNetworkState(NetworkConnectivityState newState) {
    if (_networkState != newState) {
      _networkState = newState;
      if (_networkState == NetworkConnectivityState.offline) {
        _syncState = SyncStatusState.offlineSaved;
      } else {
        // Network restored — trigger automatic background sync
        if (_pendingQueue.isNotEmpty) {
          syncNow();
        } else {
          _syncState = _failed.isEmpty ? SyncStatusState.upToDate : SyncStatusState.error;
        }
      }
      notifyListeners();
    }
  }

  void enqueueMutation({
    required String id,
    required String entityType,
    required String action,
    required Map<String, dynamic> payload,
    List<SyncOp>? ops,
    void Function(String reason)? onRejected,
  }) {
    final mutation = SyncMutation(
      id: id,
      entityType: entityType,
      action: action,
      payload: payload,
      timestamp: DateTime.now(),
      ops: ops,
      onRejected: onRejected,
    );

    _pendingQueue.add(mutation);

    if (isOffline) {
      _syncState = SyncStatusState.offlineSaved;
    } else {
      // Background sync when online
      syncNow();
    }
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (_syncState == SyncStatusState.syncing) return;

    _syncState = SyncStatusState.syncing;
    notifyListeners();

    try {
      final firestore = FirebaseGate.firestoreIfReady();

      if (firestore == null) {
        // No cloud configured (tests / local-only mode): nothing to upload.
        await Future.delayed(const Duration(milliseconds: 300));
        _pendingQueue.clear();
        _lastSyncedAt = DateTime.now();
        _syncState = isOffline ? SyncStatusState.offlineSaved : SyncStatusState.upToDate;
        return;
      }

      if (!AuthService.instance.isSignedIn) {
        // Rules reject anonymous writes. Keep everything queued until sign-in.
        _syncState = _pendingQueue.isEmpty ? SyncStatusState.upToDate : SyncStatusState.offlineSaved;
        return;
      }

      final acks = <Future<void>>[];
      for (final mutation in List<SyncMutation>.from(_pendingQueue)) {
        if (mutation.submitted) continue;
        try {
          acks.add(_submit(firestore, mutation));
        } catch (e) {
          // Could not even build the write (bad payload) — a permanent failure.
          _fail(mutation, e.toString());
        }
      }

      if (acks.isNotEmpty) {
        await Future.wait(acks).timeout(ackWait, onTimeout: () => const []);
      }
      _refreshState();
    } finally {
      notifyListeners();
    }
  }

  /// Hands [mutation] to Firestore and returns a future that completes once the
  /// server has answered (successfully or not). Never throws.
  Future<void> _submit(FirebaseFirestore firestore, SyncMutation mutation) {
    final batch = firestore.batch();
    for (final op in mutation.resolveOps()) {
      final ref = firestore.doc(op.path);
      switch (op.kind) {
        case 'delete':
          batch.delete(ref);
        case 'increment':
          batch.set(
            ref,
            {for (final e in op.data.entries) e.key: FieldValue.increment(e.value as num)},
            SetOptions(merge: true),
          );
        default:
          batch.set(ref, FirebaseGate.encode(op.data), SetOptions(merge: true));
      }
    }
    mutation.submitted = true;

    return batch.commit().then<void>((_) {
      _pendingQueue.remove(mutation);
      _lastSyncedAt = DateTime.now();
      _retryAttempt = 0;
      _refreshState();
      notifyListeners();
    }).catchError((Object e) {
      final transient = e is FirebaseException &&
          (e.code == 'unavailable' || e.code == 'deadline-exceeded' || e.code == 'aborted');
      if (transient) {
        mutation.submitted = false; // safe: the failed batch was not applied
        _scheduleRetry();
      } else {
        _fail(mutation, e is FirebaseException ? '${e.code}: ${e.message}' : e.toString());
      }
      _refreshState();
      notifyListeners();
    });
  }

  void _fail(SyncMutation mutation, String reason) {
    mutation.error = reason;
    _pendingQueue.remove(mutation);
    _failed.add(mutation);
    debugPrint('Sync rejected ${mutation.entityType} ${mutation.id}: $reason');
    try {
      mutation.onRejected?.call(reason);
    } catch (e) {
      debugPrint('onRejected handler failed: $e');
    }
  }

  void _refreshState() {
    if (_failed.isNotEmpty) {
      _syncState = SyncStatusState.error;
    } else if (_pendingQueue.isNotEmpty) {
      _syncState = SyncStatusState.offlineSaved;
    } else {
      _syncState = isOffline ? SyncStatusState.offlineSaved : SyncStatusState.upToDate;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final seconds = (5 * (1 << _retryAttempt.clamp(0, 6))).clamp(5, 300);
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: seconds), () {
      if (_pendingQueue.any((m) => !m.submitted)) syncNow();
    });
  }

  /// Puts rejected mutations back in the queue for another attempt.
  Future<void> retryFailed() async {
    if (_failed.isEmpty) return;
    for (final m in _failed) {
      m.error = null;
      m.submitted = false;
    }
    _pendingQueue.addAll(_failed);
    _failed.clear();
    _syncState = SyncStatusState.offlineSaved;
    notifyListeners();
    await syncNow();
  }

  /// Drops rejected mutations (the user has been told they were not saved).
  void discardFailed() {
    _failed.clear();
    _refreshState();
    notifyListeners();
  }

  /// Conflict Resolution System: Timestamp-based logical field merging
  /// Compares local and remote records by 'lastModified' timestamp and merges field values safely.
  Map<String, dynamic> resolveConflict({
    required Map<String, dynamic> localRecord,
    required Map<String, dynamic> remoteRecord,
  }) {
    final localTime = DateTime.tryParse(localRecord['lastModified'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final remoteTime = DateTime.tryParse(remoteRecord['lastModified'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

    // If local record is newer, local wins. If remote is newer, remote wins.
    final primary = localTime.isAfter(remoteTime) ? localRecord : remoteRecord;
    final secondary = localTime.isAfter(remoteTime) ? remoteRecord : localRecord;

    final merged = Map<String, dynamic>.from(secondary);
    primary.forEach((key, value) {
      if (value != null && (value is! String || value.isNotEmpty)) {
        merged[key] = value;
      }
    });

    merged['lastModified'] = DateTime.now().toIso8601String();
    merged['conflictResolved'] = true;
    return merged;
  }

  void stopAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void resetForTesting() {
    stopAutoSyncTimer();
    _pendingQueue.clear();
    _failed.clear();
    _retryAttempt = 0;
    _networkState = NetworkConnectivityState.online;
    _syncState = SyncStatusState.upToDate;
    _lastSyncedAt = DateTime.now();
  }

  @override
  void dispose() {
    stopAutoSyncTimer();
    super.dispose();
  }
}
