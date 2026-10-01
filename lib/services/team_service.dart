import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/team.dart';
import 'firebase_gate.dart';
import 'profile_store.dart';

class TeamService extends ChangeNotifier {
  static final TeamService instance = TeamService._();
  TeamService._();

  String? _uid;
  String? _userEmail;
  String? _displayName;
  bool _loading = false;
  List<Team> _teams = [];
  Team? _activeTeam;
  TeamRole _activeRole = TeamRole.owner;
  List<TeamMember> _members = [];

  StreamSubscription? _teamsSub;
  StreamSubscription? _membersSub;

  bool get loading => _loading;
  List<Team> get teams => List.unmodifiable(_teams);
  Team? get activeTeam => _activeTeam;
  TeamRole get activeRole => _activeRole;
  List<TeamMember> get members => List.unmodifiable(_members);

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
    if (savedActiveId != null && _teams.any((t) => t.id == savedActiveId)) {
      _activeTeam = _teams.firstWhere((t) => t.id == savedActiveId);
    } else if (_teams.isNotEmpty) {
      _activeTeam = _teams.first;
    }

    if (_activeTeam != null) {
      await _connectActiveTeamMembers(_activeTeam!.id);
    }

    _loading = false;
    notifyListeners();
  }

  void _setupDefaultFallbackTeam(String uid) {
    const defaultTeamId = 'c-default-team';
    final defaultTeam = Team(
      id: defaultTeamId,
      name: 'Primary Clinic Team',
      ownerId: uid,
      inviteCode: 'DOC-1000',
      createdAt: DateTime.now().toIso8601String(),
    );
    _teams = [defaultTeam];
    _activeTeam = defaultTeam;
    _activeRole = TeamRole.owner;
    _members = [
      TeamMember(
        uid: uid,
        email: _userEmail ?? 'user@docrs.app',
        displayName: _displayName ?? 'Dr. User',
        role: TeamRole.owner,
        joinedAt: DateTime.now().toIso8601String(),
      ),
    ];
  }

  Future<void> _createInitialDefaultTeam(String uid) async {
    final name = '${_displayName ?? 'Doctor'}\'s Clinical Team';
    await createTeam(name);
  }

  Future<void> _connectActiveTeamMembers(String teamId) async {
    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) return;

    _membersSub?.cancel();
    _membersSub = firestore
        .collection('teams')
        .doc(teamId)
        .collection('members')
        .snapshots()
        .listen((snapshot) {
      final list = <TeamMember>[];
      TeamRole myRole = TeamRole.viewer;

      for (final doc in snapshot.docs) {
        final data = FirebaseGate.decode(doc.data());
        final member = TeamMember.fromJson(data);
        list.add(member);
        if (member.uid == _uid) {
          myRole = member.role;
        }
      }

      _members = list;
      _activeRole = myRole;
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Members stream error: $e');
    });
  }

  /// Creates a new team with creator as Owner.
  Future<Team> createTeam(String name) async {
    final uid = _uid ?? 'dev-user';
    final teamId = _generateTeamId();
    final inviteCode = _generateInviteCode();
    final now = DateTime.now().toIso8601String();

    final team = Team(
      id: teamId,
      name: name.trim(),
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
    await switchTo(teamId);
    return team;
  }

  /// Joins an existing team via 6-character invite code.
  Future<Team> joinWithCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      throw const FormatException('Enter a valid invite code');
    }

    final firestore = FirebaseGate.firestoreIfReady();
    if (firestore == null) {
      throw Exception('Database service unavailable');
    }

    final query = await firestore
        .collection('teams')
        .where('inviteCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw const FormatException('No team found matching that invite code.');
    }

    final teamDoc = query.docs.first;
    final teamData = FirebaseGate.decode(teamDoc.data());
    teamData['id'] = teamDoc.id;
    final team = Team.fromJson(teamData);

    final uid = _uid ?? 'dev-user';
    final memberRef = firestore.collection('teams').doc(team.id).collection('members').doc(uid);
    final existingMember = await memberRef.get();

    if (existingMember.exists) {
      // Already a member
      await switchTo(team.id);
      return team;
    }

    // Add as Viewer (default role upon joining via code)
    final member = TeamMember(
      uid: uid,
      email: _userEmail ?? 'user@docrs.app',
      displayName: _displayName ?? 'New Member',
      role: TeamRole.viewer,
      joinedAt: DateTime.now().toIso8601String(),
    );

    await memberRef.set(member.toJson());
    if (!_teams.any((t) => t.id == team.id)) {
      _teams = [..._teams, team];
    }
    await switchTo(team.id);
    return team;
  }

  /// Switches active team context.
  Future<void> switchTo(String teamId) async {
    final target = _teams.where((t) => t.id == teamId).firstOrNull;
    if (target == null) return;

    _activeTeam = target;
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
    notifyListeners();
  }

  void unload() {
    _uid = null;
    _teamsSub?.cancel();
    _membersSub?.cancel();
    _teamsSub = null;
    _membersSub = null;
    _teams = [];
    _activeTeam = null;
    _activeRole = TeamRole.owner;
    _members = [];
    _loading = false;
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
