import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The event types and locations offered when scheduling, and in the calendar filters.
///
/// They start minimal and the clinic adds or removes its own from the dropdowns. The
/// lists are kept on this device (like the other local settings), so removing an entry
/// never touches events that already use it; those keep their text.
class EventOptionsStore extends ChangeNotifier {
  static final EventOptionsStore instance = EventOptionsStore._();

  static const defaultTypes = ['Surgery', 'Checkup', 'Follow-up'];
  static const defaultLocations = ['Bukidnon', 'Cebu'];

  /// Long enough for any real name, and well inside what the security rules allow.
  static const maxNameLength = 40;
  static const maxEntries = 20;

  static const _typesKey = 'event_options.types';
  static const _locationsKey = 'event_options.locations';

  List<String> _types = List.of(defaultTypes);
  List<String> _locations = List.of(defaultLocations);
  bool _changedSinceStart = false;

  EventOptionsStore._() {
    _load();
  }

  List<String> get types => List.unmodifiable(_types);
  List<String> get locations => List.unmodifiable(_locations);

  /// False when the name is empty, already there (ignoring case), too long, or the list is full.
  bool addType(String name) => _add(_types, name, _typesKey);
  bool addLocation(String name) => _add(_locations, name, _locationsKey);

  void removeType(String name) => _remove(_types, name, _typesKey);
  void removeLocation(String name) => _remove(_locations, name, _locationsKey);

  bool _add(List<String> list, String name, String key) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty || clean.length > maxNameLength || list.length >= maxEntries) return false;
    if (list.any((e) => e.toLowerCase() == clean.toLowerCase())) return false;
    list.add(clean);
    _changed(key, list);
    return true;
  }

  void _remove(List<String> list, String name, String key) {
    if (!list.remove(name)) return;
    _changed(key, list);
  }

  void _changed(String key, List<String> list) {
    _changedSinceStart = true;
    notifyListeners();
    _save(key, list);
  }

  Future<void> _save(String key, List<String> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, list);
    } catch (_) {
      // Storage unavailable (private window, tests): the lists still work for this session.
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // An edit made before the saved lists arrived wins; it is saved on its own.
      if (_changedSinceStart) return;
      final types = prefs.getStringList(_typesKey);
      final locations = prefs.getStringList(_locationsKey);
      if (types == null && locations == null) return;
      if (types != null) _types = List.of(types);
      if (locations != null) _locations = List.of(locations);
      notifyListeners();
    } catch (_) {
      // Nothing saved or storage unavailable: keep the defaults.
    }
  }

  /// Puts the lists back to the defaults (tests only; the app never resets them).
  @visibleForTesting
  void resetForTest() {
    _types = List.of(defaultTypes);
    _locations = List.of(defaultLocations);
    _changedSinceStart = false;
    notifyListeners();
  }
}
