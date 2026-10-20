import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';
import '../models/clinical_notification.dart';
import '../models/patient.dart';
import '../models/team.dart';
import 'auth_service.dart';
import 'firebase_gate.dart';
import 'profile_store.dart';
import 'workspace_store.dart';

class TeamService extends ChangeNotifier {
  static final TeamService instance = TeamService._();
  TeamService._();

  static final Map<String, Team> _registeredTeamsInMemory = {};

  String? _uid;
  String? _userEmail;
  String? _displayName;
  bool _loading = false;
  List<Team> _teams = [];
  Team? _activeTeam;
  TeamRole _activeRole = TeamRole.owner;
  List<TeamMember> _members = [];
  List<TeamMember> _pendingMembers = [];

  StreamSubscription? _teamsSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _joinRequestsSub;
  StreamSubscription? _pendingUsersSub;

  void _resolveCurrentUser() {
    if (FirebaseGate.isReady) {
      try {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          _uid = fbUser.uid;
          _userEmail = fbUser.email;
          if (fbUser.displayName != null && fbUser.displayName!.isNotEmpty) {
            _displayName = fbUser.displayName;
          }
          return;
        }
      } catch (_) {}
    }

    final authUser = AuthService.instance.user;
    if (authUser != null) {
      _uid = authUser.uid;
      _userEmail = authUser.email;
      if (authUser.displayName != null && authUser.displayName!.isNotEmpty) {
        _displayName = authUser.displayName;
      }
    }
  }

  bool get loading => _loading;
  List<Team> get teams => List.unmodifiable(_teams.where((t) => !t.isArchived));
  List<Team> get archivedTeams => List.unmodifiable(_teams.where((t) => t.isArchived));
  List<Team> get allTeams => List.unmodifiable(_teams);
  Team? get activeTeam => _activeTeam;
  String? get activeWorkspaceId => _activeTeam?.id;
  TeamRole get activeRole => _activeRole;
  List<TeamMember> get members => List.unmodifiable(_members);
  List<TeamMember> get pendingMembers => List.unmodifiable(_pendingMembers);

  /// Helper permission getters based on active role
  bool get canViewPatients => _activeRole.canViewPatients;
  bool get canEditPatients => _activeRole.canEditPatients;
  bool get canSeeVisits => _activeRole.canSeeVisits;
  bool get canWriteVisits => _activeRole.canWriteVisits;
  bool get canManageMembers => _activeRole.canManageMembers;

  String _localKey(String uid) => 'teams.active.$uid';

  /// Loads teams for the signed in user. Call after authentication.
  Future<void> load(String uid, {String? userEmail, String? displayName}) async {
    _uid = uid;
    _userEmail = userEmail ?? 'user@docrs.app';
    _displayName = displayName ?? ProfileStore.instance.doctorName.text.trim();
    if (_displayName == null || _displayName!.isEmpty) {
      _displayName = 'Dr. User';
    }
    _loading = true;
    notifyListeners();

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) {
      // In unit test / offline non-Firebase environment, create a default in-memory team
      _setupDefaultFallbackTeam(uid);
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      _teamsSub?.cancel();

      // Listen to both collectionGroup('members') and teams collection
      _teamsSub = firestore
          .collectionGroup('members')
          .where('uid', isEqualTo: uid)
          .snapshots()
          .listen((_) async {
        await _fetchAndMergeUserTeams(firestore, uid);
      }, onError: (Object e) async {
        debugPrint('TeamService collectionGroup error: $e');
        await _fetchAndMergeUserTeams(firestore, uid);
      });

      // Execute initial multi-source fetch
      await _fetchAndMergeUserTeams(firestore, uid);
    } catch (e) {
      debugPrint('TeamService load exception: $e');
      if (_teams.isEmpty) {
        _setupDefaultFallbackTeam(uid);
      }
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchAndMergeUserTeams(dynamic firestore, String uid) async {
    final teamMap = <String, Team>{};

    // 1. Fetch from collectionGroup('members')
    try {
      final memberSnap = await firestore
          .collectionGroup('members')
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in memberSnap.docs) {
        final parentRef = doc.reference.parent.parent;
        if (parentRef != null) {
          final tDoc = await parentRef.get();
          if (tDoc.exists && tDoc.data() != null) {
            final data = FirebaseGate.decode(tDoc.data()!);
            data['id'] = tDoc.id;
            teamMap[tDoc.id] = Team.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('member cgroup fetch error: $e');
    }

    // 2. Fetch teams where ownerId == uid
    try {
      final ownerSnap = await firestore
          .collection('teams')
          .where('ownerId', isEqualTo: uid)
          .get();
      for (final doc in ownerSnap.docs) {
        if (doc.exists && doc.data() != null) {
          final data = FirebaseGate.decode(doc.data()!);
          data['id'] = doc.id;
          teamMap[doc.id] = Team.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('owner teams fetch error: $e');
    }

    // 3. Broad scan teams collection (up to 100) for membership or ownership
    try {
      final teamsSnap = await firestore.collection('teams').limit(100).get();
      for (final doc in teamsSnap.docs) {
        final tId = doc.id;
        if (doc.exists && doc.data() != null && !teamMap.containsKey(tId)) {
          final data = FirebaseGate.decode(doc.data()!);
          data['id'] = tId;
          final team = Team.fromJson(data);
          if (team.ownerId == uid) {
            teamMap[tId] = team;
          } else {
            // Check member subcollection doc
            final mDoc = await firestore
                .collection('teams')
                .doc(tId)
                .collection('members')
                .doc(uid)
                .get();
            if (mDoc.exists) {
              teamMap[tId] = team;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('all teams scan error: $e');
    }

    if (teamMap.isEmpty) {
      // First time user: auto create initial default team
      await _createInitialDefaultTeam(uid);
      return;
    }

    _teams = teamMap.values.toList();
    _teams.sort((a, b) => a.name.compareTo(b.name));

    // Restore active team preference
    final prefs = await SharedPreferences.getInstance();
    final savedActiveId = prefs.getString(_localKey(uid));
    final nonArchived = _teams.where((t) => !t.isArchived).toList();
    if (savedActiveId != null && nonArchived.any((t) => t.id == savedActiveId)) {
      _activeTeam = nonArchived.firstWhere((t) => t.id == savedActiveId);
    } else if (nonArchived.isNotEmpty) {
      _activeTeam = nonArchived.first;
    } else if (_teams.isNotEmpty) {
      _activeTeam = _teams.first;
    }

    if (_activeTeam != null) {
      WorkspaceStore.instance.setActiveWorkspace(_activeTeam!.id, workspace: _activeTeam);
      await _connectActiveTeamMembers(_activeTeam!.id);
      PatientRepository.connect(_activeTeam!.id);
      CalendarEventRepository().connect(_activeTeam!.id);
      ClinicalNotificationRepository().connect(_activeTeam!.id);
    }

    _loading = false;
    notifyListeners();
  }

  void _setupDefaultFallbackTeam(String uid) {
    const defaultTeamId = 'c-default-team';
    final defaultTeam = Team(
      id: defaultTeamId,
      name: 'Primary Clinic Team',
      location: 'Metro Eye Center, Main Branch',
      ownerId: uid,
      inviteCode: 'DOC-1000',
      createdAt: DateTime.now().toIso8601String(),
    );
    _teams = [defaultTeam];
    _activeTeam = defaultTeam;
    _activeRole = TeamRole.owner;
    _pendingMembers = [];
    _members = [
      TeamMember(
        uid: uid,
        email: _userEmail ?? 'user@docrs.app',
        displayName: _displayName ?? 'Dr. User',
        role: TeamRole.owner,
        joinedAt: DateTime.now().toIso8601String(),
      ),
    ];
    _registeredTeamsInMemory[defaultTeam.inviteCode] = defaultTeam;
    WorkspaceStore.instance.setActiveWorkspace(defaultTeam.id, workspace: defaultTeam);
    PatientRepository.connect(defaultTeam.id);
    CalendarEventRepository().connect(defaultTeam.id);
    ClinicalNotificationRepository().connect(defaultTeam.id);
  }

  Future<void> _createInitialDefaultTeam(String uid) async {
    final name = '${_displayName ?? 'Doctor'}\'s Clinical Team';
    await createTeam(name, location: 'Metro Eye Center, Main Branch');
  }

  Future<void> _connectActiveTeamMembers(String teamId) async {
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;

    _membersSub?.cancel();
    _joinRequestsSub?.cancel();
    _pendingUsersSub?.cancel();

    final activeMap = <String, TeamMember>{};
    final pendingMap = <String, TeamMember>{};

    void recomputeAndNotify() {
      TeamRole myRole = (_activeTeam != null && _activeTeam!.ownerId == _uid)
          ? TeamRole.owner
          : TeamRole.viewer;

      for (final member in activeMap.values) {
        if (member.uid == _uid) {
          myRole = member.role;
        }
      }

      if (_activeTeam != null && _activeTeam!.ownerId == _uid) {
        myRole = TeamRole.owner;
      }

      _members = activeMap.values.toList();
      _pendingMembers = pendingMap.values.where((p) => !activeMap.containsKey(p.uid)).toList();
      _activeRole = myRole;
      notifyListeners();
    }

    _membersSub = firestore
        .collection('teams')
        .doc(teamId)
        .collection('members')
        .snapshots()
        .listen((snapshot) {
      activeMap.clear();
      pendingMap.removeWhere((_, member) => member.requestedWorkspaceId == teamId || member.status == 'pending');

      for (final doc in snapshot.docs) {
        final data = FirebaseGate.decode(doc.data());
        final member = TeamMember.fromJson(data);
        if (member.isPending) {
          pendingMap[member.uid] = member.copyWith(requestedWorkspaceId: teamId);
        } else {
          activeMap[member.uid] = member;
          pendingMap.remove(member.uid);
        }
      }
      recomputeAndNotify();
    }, onError: (Object e) {
      debugPrint('[TeamService] Members stream error for workspace $teamId: $e');
    });

    _joinRequestsSub = firestore
        .collection('teams')
        .doc(teamId)
        .collection('joinRequests')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = FirebaseGate.decode(doc.data());
        final member = TeamMember.fromJson(data);
        if (!activeMap.containsKey(member.uid)) {
          pendingMap[member.uid] = member.copyWith(requestedWorkspaceId: teamId);
        }
      }
      recomputeAndNotify();
    }, onError: (Object e) {
      debugPrint('[TeamService] JoinRequests stream error for workspace $teamId: $e');
    });

    _pendingUsersSub = firestore
        .collection('users')
        .where('status', isEqualTo: 'pending')
        .where('requestedWorkspaceId', isEqualTo: teamId)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final uData = FirebaseGate.decode(doc.data());
        final uid = doc.id;
        if (!activeMap.containsKey(uid)) {
          final reqRole = uData['requestedRole'] as String?;
          pendingMap[uid] = TeamMember(
            uid: uid,
            email: uData['email'] as String? ?? 'user@docrs.app',
            displayName: uData['displayName'] as String? ?? uData['name'] as String? ?? 'Pending Account',
            role: TeamRole.viewer,
            joinedAt: uData['createdAt'] as String? ?? DateTime.now().toIso8601String(),
            status: 'pending',
            requestedWorkspaceId: teamId,
            requestedRole: reqRole,
          );
        }
      }
      recomputeAndNotify();
    }, onError: (Object e) {
      debugPrint('[TeamService] Pending users stream error for workspace $teamId: $e');
    });
  }

  /// Real-time stream of pending approval members filtered by [workspaceId].
  Stream<List<TeamMember>> streamPendingMembers(String? workspaceId) {
    final effectiveId = workspaceId ?? activeWorkspaceId;
    late StreamController<List<TeamMember>> controller;
    StreamSubscription? subMembers;
    StreamSubscription? subJoinRequests;

    List<TeamMember> currentPendingForEffective() {
      if (effectiveId == null || effectiveId.isEmpty) {
        return List<TeamMember>.from(_pendingMembers);
      }
      return _pendingMembers
          .where((m) => m.requestedWorkspaceId == effectiveId || m.requestedWorkspaceId == null)
          .toList();
    }

    void emitMerged(List<TeamMember> firestoreList) {
      if (controller.isClosed) return;
      final mergedMap = <String, TeamMember>{};
      for (final p in currentPendingForEffective()) {
        mergedMap[p.uid] = p;
      }
      for (final m in firestoreList) {
        mergedMap[m.uid] = m;
      }
      controller.add(mergedMap.values.toList());
    }

    void serviceListener() {
      if (!controller.isClosed) {
        emitMerged([]);
      }
    }

    controller = StreamController<List<TeamMember>>.broadcast(
      onListen: () {
        controller.add(currentPendingForEffective());
        addListener(serviceListener);

        final firestore = FirebaseGate.firestoreIfReady();
        if (firestore != null && effectiveId != null && effectiveId.isNotEmpty) {
          final fMembers = <String, TeamMember>{};
          final fRequests = <String, TeamMember>{};

          void updateFirestore() {
            final combined = <String, TeamMember>{...fMembers, ...fRequests};
            emitMerged(combined.values.toList());
          }

          subMembers = firestore
              .collection('teams')
              .doc(effectiveId)
              .collection('members')
              .snapshots()
              .listen((snap) {
            fMembers.clear();
            for (final doc in snap.docs) {
              final d = FirebaseGate.decode(doc.data());
              final m = TeamMember.fromJson(d);
              if (m.isPending) {
                fMembers[m.uid] = m.copyWith(requestedWorkspaceId: effectiveId);
              }
            }
            updateFirestore();
          }, onError: (e) {
            debugPrint('[streamPendingMembers] members stream error: $e');
          });

          subJoinRequests = firestore
              .collection('teams')
              .doc(effectiveId)
              .collection('joinRequests')
              .snapshots()
              .listen((snap) {
            fRequests.clear();
            for (final doc in snap.docs) {
              final d = FirebaseGate.decode(doc.data());
              final m = TeamMember.fromJson(d);
              fRequests[m.uid] = m.copyWith(requestedWorkspaceId: effectiveId);
            }
            updateFirestore();
          }, onError: (e) {
            debugPrint('[streamPendingMembers] joinRequests stream error: $e');
          });
        }
      },
      onCancel: () {
        removeListener(serviceListener);
        subMembers?.cancel();
        subJoinRequests?.cancel();
      },
    );

    return controller.stream;
  }

  /// Creates a new team with creator as Owner.
  Future<Team> createTeam(String name, {String location = ''}) async {
    _resolveCurrentUser();
    final uid = _uid ?? 'dev-user';
    final teamId = _generateTeamId();
    final inviteCode = _generateInviteCode();
    final now = DateTime.now().toIso8601String();

    final team = Team(
      id: teamId,
      name: name.trim(),
      location: location.trim(),
      ownerId: uid,
      inviteCode: inviteCode,
      createdAt: now,
    );

    final member = TeamMember(
      uid: uid,
      email: _userEmail ?? 'user@docrs.app',
      displayName: _displayName ?? 'Doctor',
      role: TeamRole.owner,
      joinedAt: now,
    );

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      final batch = firestore.batch();
      final teamRef = firestore.collection('teams').doc(teamId);
      batch.set(teamRef, team.toJson());

      final memberRef = teamRef.collection('members').doc(uid);
      batch.set(memberRef, member.toJson());

      await batch.commit();
    }

    _teams = [..._teams, team];
    _registeredTeamsInMemory[team.inviteCode] = team;
    await switchTo(teamId);
    return team;
  }

  /// Joins an existing team via 6-character invite code.
  Future<Team> joinWithCode(String code, {String requestedRole = 'assistant'}) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      throw const FormatException('Enter a valid invite code');
    }

    _resolveCurrentUser();
    final uid = _uid ?? 'dev-user';
    final email = _userEmail ?? 'user@docrs.app';
    final displayName = _displayName ?? 'New Member';
    _uid = uid;
    _userEmail = email;
    _displayName = displayName;

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) {
      final target = _teams.where((t) => t.inviteCode == cleanCode).firstOrNull ??
          _registeredTeamsInMemory[cleanCode];
      if (target == null) {
        throw const FormatException('No team found matching that invite code.');
      }
      if (target.ownerId == uid) {
        await switchTo(target.id);
        return target;
      }
      final existingActive = _members.where((m) => m.uid == uid && !m.isPending && _activeTeam?.id == target.id).firstOrNull;
      if (existingActive != null) {
        await switchTo(target.id);
        return target;
      }
      final pendingMember = TeamMember(
        uid: uid,
        email: email,
        displayName: displayName,
        role: TeamRole.viewer,
        joinedAt: DateTime.now().toIso8601String(),
        status: 'pending',
        requestedWorkspaceId: target.id,
        requestedRole: requestedRole,
      );
      if (!_pendingMembers.any((m) => m.uid == uid)) {
        _pendingMembers.add(pendingMember);
        notifyListeners();
      }
      return target;
    }

    QuerySnapshot<Map<String, dynamic>> query;
    try {
      query = await firestore
          .collection('teams')
          .where('inviteCode', isEqualTo: cleanCode)
          .limit(1)
          .get();
    } catch (e, stackTrace) {
      debugPrint('[TeamService.joinWithCode] Querying team with invite code $cleanCode failed: $e\n$stackTrace');
      rethrow;
    }

    if (query.docs.isEmpty) {
      throw const FormatException('No team found matching that invite code.');
    }

    final teamDoc = query.docs.first;
    final teamData = FirebaseGate.decode(teamDoc.data());
    teamData['id'] = teamDoc.id;
    final team = Team.fromJson(teamData);

    final memberRef = firestore.collection('teams').doc(team.id).collection('members').doc(uid);
    DocumentSnapshot<Map<String, dynamic>>? existingMember;
    try {
      existingMember = await memberRef.get();
    } catch (e) {
      debugPrint('[TeamService.joinWithCode] Notice checking existing team member: $e');
    }

    if (existingMember != null && existingMember.exists && existingMember.data() != null) {
      final existingData = FirebaseGate.decode(existingMember.data()!);
      final existingStatus = (existingData['status'] as String?)?.toLowerCase();
      final isApproved = existingData['isApproved'] as bool? ?? true;
      if (existingStatus == 'pending' || !isApproved) {
        return team;
      }
      await switchTo(team.id);
      return team;
    }

    final now = DateTime.now().toIso8601String();
    final member = TeamMember(
      uid: uid,
      email: email,
      displayName: displayName,
      role: TeamRole.viewer,
      joinedAt: now,
      status: 'pending',
      requestedWorkspaceId: team.id,
      requestedRole: requestedRole,
    );

    final memberPayload = <String, dynamic>{
      'uid': uid,
      'email': member.email,
      'displayName': member.displayName,
      'role': 'viewer',
      'requestedRole': requestedRole,
      'status': 'pending',
      'isApproved': false,
      'targetWorkspaceId': team.id,
      'requestedWorkspaceId': team.id,
      'workspaceId': team.id,
      'teamId': team.id,
      'joinedAt': now,
      'requestedAt': now,
      'inviteCode': cleanCode,
      'createdAt': now,
      'updatedAt': now,
    };

    final userPayload = <String, dynamic>{
      'uid': uid,
      'email': member.email,
      'displayName': member.displayName,
      'status': 'pending',
      'isApproved': false,
      'requestedRole': requestedRole,
      'targetWorkspaceId': team.id,
      'requestedWorkspaceId': team.id,
      'workspaceId': team.id,
      'teamId': team.id,
      'updatedAt': now,
    };

    try {
      final batch = firestore.batch();
      batch.set(memberRef, memberPayload, SetOptions(merge: true));

      final joinRequestRef = firestore.collection('teams').doc(team.id).collection('joinRequests').doc(uid);
      batch.set(joinRequestRef, memberPayload, SetOptions(merge: true));

      final userRef = firestore.collection('users').doc(uid);
      batch.set(userRef, userPayload, SetOptions(merge: true));

      await batch.commit();
      debugPrint('[TeamService.joinWithCode] Successfully submitted join request for user $uid to workspace ${team.id} (${team.name})');
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('[TeamService.joinWithCode] FirebaseException writing join request (code: ${e.code}, path: teams/${team.id}/members/$uid, message: ${e.message})\n$stackTrace');
      if (e.code == 'permission-denied') {
        debugPrint('[TeamService.joinWithCode] Permission restriction: Current user $uid does not have permission to write to teams/${team.id}/members/$uid or users/$uid.');
      }
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[TeamService.joinWithCode] Unexpected error writing join request to workspace ${team.id}: $e\n$stackTrace');
      rethrow;
    }

    if (_activeTeam?.id == team.id) {
      if (!_pendingMembers.any((m) => m.uid == uid)) {
        _pendingMembers.add(member);
        notifyListeners();
      }
    }
    return team;
  }

  /// Switches active team context.
  Future<void> switchTo(String teamId) async {
    final target = _teams.where((t) => t.id == teamId).firstOrNull;
    if (target == null) return;

    _activeTeam = target;
    if (_uid != null && target.ownerId == _uid) {
      _activeRole = TeamRole.owner;
    }
    WorkspaceStore.instance.setActiveWorkspace(teamId, workspace: target);

    final uid = _uid;
    if (uid != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_localKey(uid), teamId);
      } catch (e) {
        debugPrint('Failed persisting active team selection: $e');
      }
    }

    await _connectActiveTeamMembers(teamId);
    PatientRepository.connect(teamId);
    CalendarEventRepository().connect(teamId);
    ClinicalNotificationRepository().connect(teamId);
    notifyListeners();
  }

  /// Updates member role in active team (Owner only).
  Future<void> updateMemberRole(String memberUid, TeamRole newRole) async {
    if (!canManageMembers) {
      throw const FormatException('Only the team owner can change member roles.');
    }
    final active = _activeTeam;
    if (active == null) return;

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      await firestore
          .collection('teams')
          .doc(active.id)
          .collection('members')
          .doc(memberUid)
          .update({'role': newRole.name});
    }

    final idx = _members.indexWhere((m) => m.uid == memberUid);
    if (idx != -1) {
      final old = _members[idx];
      _members[idx] = TeamMember(
        uid: old.uid,
        email: old.email,
        displayName: old.displayName,
        role: newRole,
        joinedAt: old.joinedAt,
      );
      notifyListeners();
    }
  }

  /// Removes member from active team (Owner only).
  Future<void> removeMember(String memberUid) async {
    if (!canManageMembers) {
      throw const FormatException('Only the team owner can remove members.');
    }
    final active = _activeTeam;
    if (active == null) return;
    if (memberUid == active.ownerId) {
      throw const FormatException('The team owner cannot be removed. Transfer ownership first.');
    }

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      await firestore
          .collection('teams')
          .doc(active.id)
          .collection('members')
          .doc(memberUid)
          .delete();
    }

    _members.removeWhere((m) => m.uid == memberUid);
    notifyListeners();
  }

  /// Leaves the current active team.
  Future<void> leaveTeam() async {
    final active = _activeTeam;
    final uid = _uid;
    if (active == null || uid == null) return;
    if (uid == active.ownerId) {
      throw const FormatException('Team owner cannot leave without transferring ownership first.');
    }

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      await firestore
          .collection('teams')
          .doc(active.id)
          .collection('members')
          .doc(uid)
          .delete();
    }

    _teams.removeWhere((t) => t.id == active.id);
    _activeTeam = _teams.isNotEmpty ? _teams.first : null;
    PatientRepository.connect(_activeTeam?.id);
    CalendarEventRepository().connect(_activeTeam?.id);
    notifyListeners();
  }

  /// Transfers team ownership to another member.
  Future<void> transferOwnership(String newOwnerUid) async {
    if (!canManageMembers) {
      throw const FormatException('Only team owner can transfer ownership.');
    }
    final active = _activeTeam;
    final currentUid = _uid;
    if (active == null || currentUid == null) return;

    final targetMember = _members.where((m) => m.uid == newOwnerUid).firstOrNull;
    if (targetMember == null) {
      throw const FormatException('Selected user is not a member of this team.');
    }

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      final batch = firestore.batch();
      final teamRef = firestore.collection('teams').doc(active.id);
      batch.update(teamRef, {'ownerId': newOwnerUid});

      final oldOwnerRef = teamRef.collection('members').doc(currentUid);
      batch.update(oldOwnerRef, {'role': TeamRole.editor.name});

      final newOwnerRef = teamRef.collection('members').doc(newOwnerUid);
      batch.update(newOwnerRef, {'role': TeamRole.owner.name});

      await batch.commit();
    }

    _activeTeam = active.copyWith(ownerId: newOwnerUid);
    _activeRole = TeamRole.editor;
    notifyListeners();
  }

  /// Regenerates invite code for active team (Owner only).
  Future<String> regenerateInviteCode() async {
    if (!canManageMembers) {
      throw const FormatException('Only team owner can regenerate invite codes.');
    }
    final active = _activeTeam;
    if (active == null) throw Exception('No active team');

    final newCode = _generateInviteCode();
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      await firestore.collection('teams').doc(active.id).update({'inviteCode': newCode});
    }

    _activeTeam = active.copyWith(inviteCode: newCode);
    notifyListeners();
    return newCode;
  }

  /// Deletes active team (Owner only).
  Future<void> deleteTeam() async {
    if (!canManageMembers) {
      throw const FormatException('Only team owner can delete the team.');
    }
    final active = _activeTeam;
    if (active == null) return;

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      await firestore.collection('teams').doc(active.id).delete();
    }

    _teams.removeWhere((t) => t.id == active.id);
    _activeTeam = _teams.isNotEmpty ? _teams.first : null;
    PatientRepository.connect(_activeTeam?.id);
    CalendarEventRepository().connect(_activeTeam?.id);
    notifyListeners();
  }

  /// Updates team details (name, location) in Firestore and memory.
  Future<Team> updateTeam(String teamId, {required String name, String? location}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const FormatException('Team Name cannot be empty');
    }

    final idx = _teams.indexWhere((t) => t.id == teamId);
    if (idx == -1) {
      throw StateError('Team not found');
    }

    final existing = _teams[idx];
    final updated = existing.copyWith(
      name: cleanName,
      location: location?.trim() ?? existing.location,
    );

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      final updateData = <String, dynamic>{
        'name': updated.name,
        'location': updated.location,
      };
      await firestore.collection('teams').doc(teamId).update(updateData);
    }

    _teams[idx] = updated;
    if (_activeTeam?.id == teamId) {
      _activeTeam = updated;
      WorkspaceStore.instance.setActiveWorkspace(teamId, workspace: updated);
    }
    notifyListeners();
    return updated;
  }

  /// Convenience method to update team name.
  Future<void> updateTeamName(String teamId, String newName) async {
    await updateTeam(teamId, name: newName);
  }

  /// Soft deletes / archives a team workspace (isArchived: true).
  /// Prevents archiving the active workspace without switching first.
  Future<void> archiveTeam(String teamId) async {
    if (_activeTeam?.id == teamId) {
      throw StateError('Cannot archive active workspace. Switch to another workspace first.');
    }

    final idx = _teams.indexWhere((t) => t.id == teamId);
    if (idx == -1) {
      throw StateError('Team not found');
    }

    final existing = _teams[idx];
    final updated = existing.copyWith(isArchived: true);

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      await firestore.collection('teams').doc(teamId).update({'isArchived': true});
    }

    _teams[idx] = updated;
    _registeredTeamsInMemory[existing.inviteCode] = updated;
    notifyListeners();
  }

  /// Restores / unarchives a previously archived workspace (isArchived: false).
  Future<void> restoreTeam(String teamId) async {
    final idx = _teams.indexWhere((t) => t.id == teamId);
    if (idx == -1) {
      throw StateError('Team not found');
    }

    final existing = _teams[idx];
    final updated = existing.copyWith(isArchived: false);

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      await firestore.collection('teams').doc(teamId).update({'isArchived': false});
    }

    _teams[idx] = updated;
    _registeredTeamsInMemory[existing.inviteCode] = updated;
    notifyListeners();
  }

  /// Helper to check if current user has owner/admin privileges to manage a team.
  bool canManageTeam(Team team) {
    if (_uid == null) return true;
    if (team.ownerId.isEmpty || team.ownerId == _uid) return true;
    if (_activeRole == TeamRole.owner) return true;
    return false;
  }

  /// Approves a pending user request, assigning them a team role and updating Firestore status.
  Future<void> approvePendingMember(String memberUid, TeamRole assignedRole, {String? targetWorkspaceId}) async {
    if (!canManageMembers) {
      throw const FormatException('Only team admins/owners can approve pending members.');
    }
    final effectiveWsId = targetWorkspaceId ?? activeWorkspaceId;
    final active = (effectiveWsId != null && effectiveWsId.isNotEmpty)
        ? (_teams.where((t) => t.id == effectiveWsId).firstOrNull ?? _activeTeam)
        : _activeTeam;
    if (active == null) return;

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      final batch = firestore.batch();

      final memberRef = firestore
          .collection('teams')
          .doc(active.id)
          .collection('members')
          .doc(memberUid);
      batch.set(memberRef, {
        'uid': memberUid,
        'role': assignedRole.name,
        'status': 'active',
        'isApproved': true,
        'joinedAt': DateTime.now().toIso8601String(),
        'requestedWorkspaceId': active.id,
        'workspaceId': active.id,
        'teamId': active.id,
      }, SetOptions(merge: true));

      final userRoleStr = (assignedRole == TeamRole.owner)
          ? 'admin'
          : (assignedRole == TeamRole.editor ? 'physician' : 'staff');

      final userRef = firestore.collection('users').doc(memberUid);
      batch.set(userRef, {
        'role': userRoleStr,
        'teamRole': assignedRole.name,
        'status': 'active',
        'isApproved': true,
        'teamId': active.id,
        'workspaceId': active.id,
        'activeWorkspaceId': active.id,
        'requestedWorkspaceId': active.id,
      }, SetOptions(merge: true));

      final joinRequestRef = firestore
          .collection('teams')
          .doc(active.id)
          .collection('joinRequests')
          .doc(memberUid);
      batch.delete(joinRequestRef);

      try {
        await batch.commit();
        debugPrint('[TeamService.approvePendingMember] Approved member $memberUid in workspace ${active.id} as ${assignedRole.name}');
      } on FirebaseException catch (e, stackTrace) {
        debugPrint('[TeamService.approvePendingMember] FirebaseException during approval: ${e.code} ${e.message}\n$stackTrace');
        rethrow;
      } catch (e, stackTrace) {
        debugPrint('[TeamService.approvePendingMember] Error during approval: $e\n$stackTrace');
        rethrow;
      }
    }

    final idx = _pendingMembers.indexWhere((m) => m.uid == memberUid);
    TeamMember target;
    if (idx != -1) {
      target = _pendingMembers.removeAt(idx);
    } else {
      target = TeamMember(
        uid: memberUid,
        email: 'user@docrs.app',
        displayName: 'Approved Member',
        role: assignedRole,
        joinedAt: DateTime.now().toIso8601String(),
        status: 'active',
        requestedWorkspaceId: active.id,
      );
    }

    final approvedMember = target.copyWith(
      role: assignedRole,
      status: 'active',
      requestedWorkspaceId: active.id,
    );

    _members.removeWhere((m) => m.uid == memberUid);
    _members.add(approvedMember);
    notifyListeners();
  }

  /// Declines/rejects a pending member request.
  Future<void> rejectPendingMember(String memberUid) async {
    if (!canManageMembers) {
      throw const FormatException('Only team admins/owners can decline member requests.');
    }
    final active = _activeTeam;
    if (active == null) return;

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore != null) {
      final batch = firestore.batch();
      final memberRef = firestore
          .collection('teams')
          .doc(active.id)
          .collection('members')
          .doc(memberUid);
      batch.delete(memberRef);

      final userRef = firestore.collection('users').doc(memberUid);
      batch.set(userRef, {
        'status': 'rejected',
        'isApproved': false,
        'requestedWorkspaceId': null,
      }, SetOptions(merge: true));

      final joinRequestRef = firestore
          .collection('teams')
          .doc(active.id)
          .collection('joinRequests')
          .doc(memberUid);
      batch.delete(joinRequestRef);

      await batch.commit();
    }

    _pendingMembers.removeWhere((m) => m.uid == memberUid);
    notifyListeners();
  }

  @visibleForTesting
  void addPendingMemberForTesting(TeamMember member) {
    _pendingMembers.add(member);
    notifyListeners();
  }

  void unload() {
    _uid = null;
    _userEmail = null;
    _displayName = null;
    _teamsSub?.cancel();
    _membersSub?.cancel();
    _pendingUsersSub?.cancel();
    _teamsSub = null;
    _membersSub = null;
    _pendingUsersSub = null;
    _teams = [];
    _activeTeam = null;
    _activeRole = TeamRole.owner;
    _members = [];
    _pendingMembers = [];
    _loading = false;
    PatientRepository.disconnect();
    CalendarEventRepository().disconnect();
    ClinicalNotificationRepository().disconnect();
    WorkspaceStore.instance.setActiveWorkspace(null, workspace: null);
    notifyListeners();
  }

  static String _generateTeamId() {
    final rng = Random.secure();
    final suffix = List.generate(6, (_) => rng.nextInt(36).toRadixString(36)).join();
    return 't-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$suffix';
  }

  static String _generateInviteCode() {
    final rng = Random.secure();
    final num = rng.nextInt(9000) + 1000;
    return 'DOC-$num';
  }
}
