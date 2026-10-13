import 'package:flutter/widgets.dart';
import '../models/team.dart';
import 'team_service.dart';

/// Global state management solution for broadcasting active workspace information
/// across the entire application (analogous to React Context / Redux workspace slice).
class WorkspaceStore extends ChangeNotifier {
  static final WorkspaceStore instance = WorkspaceStore._internal();

  String? _activeWorkspaceId;
  Team? _activeWorkspace;

  WorkspaceStore._internal() {
    _syncWithTeamService();
    TeamService.instance.addListener(_syncWithTeamService);
  }

  /// The currently active workspace identifier.
  String? get activeWorkspaceId => _activeWorkspaceId;

  /// The currently active team workspace model, if available.
  Team? get activeWorkspace => _activeWorkspace;

  void _syncWithTeamService() {
    final active = TeamService.instance.activeTeam;
    final newId = active?.id;
    if (_activeWorkspaceId != newId || _activeWorkspace != active) {
      _activeWorkspaceId = newId;
      _activeWorkspace = active;
      notifyListeners();
    }
  }

  /// Sets the active workspace and broadcasts change to all listeners.
  void setActiveWorkspace(String? workspaceId, {Team? workspace}) {
    if (_activeWorkspaceId != workspaceId || _activeWorkspace != workspace) {
      _activeWorkspaceId = workspaceId;
      _activeWorkspace = workspace;
      notifyListeners();
    }
  }

  /// Requests a team switch through TeamService.
  Future<void> switchWorkspace(String workspaceId) async {
    await TeamService.instance.switchTo(workspaceId);
    _syncWithTeamService();
  }

  /// Clears active workspace upon logout or reset.
  void clear() {
    _activeWorkspaceId = null;
    _activeWorkspace = null;
    notifyListeners();
  }
}

/// InheritedWidget providing React Context-style scoping for [WorkspaceStore].
class WorkspaceScope extends InheritedNotifier<WorkspaceStore> {
  const WorkspaceScope({
    super.key,
    required WorkspaceStore store,
    required super.child,
  }) : super(notifier: store);

  /// Access the active workspace ID from the nearest [WorkspaceScope].
  static String? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WorkspaceScope>()?.notifier?.activeWorkspaceId;
  }

  /// Access the [WorkspaceStore] notifier instance from context.
  static WorkspaceStore? storeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WorkspaceScope>()?.notifier;
  }
}

/// Convenience extension on [BuildContext] to access the active workspace ID.
extension WorkspaceContextExtension on BuildContext {
  String? get activeWorkspaceId => WorkspaceScope.of(this) ?? WorkspaceStore.instance.activeWorkspaceId;
}
