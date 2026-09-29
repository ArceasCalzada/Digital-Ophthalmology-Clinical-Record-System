import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How long before an appointment its reminder alert goes out.
///
/// One clinic-wide choice made in Settings, not asked again for every event: each
/// new event takes the value that is set when it is saved. Events that already
/// exist keep the value they were saved with. Kept on this device, like the other
/// local settings.
class ReminderSettingsStore extends ChangeNotifier {
  static final ReminderSettingsStore instance = ReminderSettingsStore._();

  /// The choices offered in Settings: minutes before the event, and their labels.
  static const options = <int, String>{
    15: '15 minutes before',
    30: '30 minutes before',
    60: '1 hour before',
    1440: '1 day before',
  };

  static const defaultMinutes = 30;
  static const _key = 'reminder_settings.minutes_before';

  int _minutes = defaultMinutes;
  bool _changedSinceStart = false;

  ReminderSettingsStore._() {
    _load();
  }

  /// Minutes before an event that its reminder alert goes out.
  int get minutesBefore => _minutes;

  set minutesBefore(int minutes) {
    if (!options.containsKey(minutes) || minutes == _minutes) return;
    _minutes = minutes;
    _changedSinceStart = true;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, _minutes);
    } catch (_) {
      // Storage unavailable (private window, tests): the choice still holds for this session.
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // A choice made before the saved one arrived wins; it is saved on its own.
      if (_changedSinceStart) return;
      final saved = prefs.getInt(_key);
      if (saved == null || !options.containsKey(saved)) return;
      _minutes = saved;
      notifyListeners();
    } catch (_) {
      // Nothing saved or storage unavailable: keep the default.
    }
  }

  /// Puts the setting back to the default (tests only; the app never resets it).
  @visibleForTesting
  void resetForTest() {
    _minutes = defaultMinutes;
    _changedSinceStart = false;
    notifyListeners();
  }
}
