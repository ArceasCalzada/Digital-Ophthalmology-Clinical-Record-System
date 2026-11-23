import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Route observer that notifies [InactivityGuard] on any route navigation,
/// modal display, or dialog dismissal.
class InactivityRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    InactivityGuard.recordActivity();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    InactivityGuard.recordActivity();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    InactivityGuard.recordActivity();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    InactivityGuard.recordActivity();
  }
}

/// Calls [onTimeout] when nothing has interacted with the app for [timeout].
///
/// Tracks active user interactions across the workspace:
/// - Pointer events (mouse clicks, movement, hover, stylus, touch, trackpad)
/// - Hardware and virtual keystrokes
/// - Scrolling gestures on all scrollables
/// - Navigator route transitions
///
/// Any interaction resets the countdown. If [timeout] is null or [isLocked] is true,
/// the countdown is inactive/paused.
class InactivityGuard extends StatefulWidget {
  final Duration? timeout;
  final bool isLocked;
  final VoidCallback onTimeout;
  final Widget child;

  const InactivityGuard({
    super.key,
    required this.timeout,
    this.isLocked = false,
    required this.onTimeout,
    required this.child,
  });

  /// Static method to manually record user activity from external components (e.g. RouteObservers).
  static void recordActivity() {
    for (final state in _activeStates) {
      state.recordUserActivity();
    }
  }

  static final List<InactivityGuardState> _activeStates = [];

  @override
  State<InactivityGuard> createState() => InactivityGuardState();
}

class InactivityGuardState extends State<InactivityGuard> {
  Timer? _timer;

  /// Visible for testing whether the inactivity timer is currently active.
  bool get isTimerActive => _timer?.isActive ?? false;

  @override
  void initState() {
    super.initState();
    InactivityGuard._activeStates.add(this);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    _restart();
  }

  @override
  void didUpdateWidget(InactivityGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeout != widget.timeout || oldWidget.isLocked != widget.isLocked) {
      _restart();
    }
  }

  bool _handleHardwareKey(KeyEvent event) {
    recordUserActivity();
    return false;
  }

  /// Records user activity and resets the timeout timer unless currently locked.
  void recordUserActivity() {
    if (widget.isLocked) return;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (widget.isLocked) return;
    final duration = widget.timeout;
    if (duration == null) return;
    _timer = Timer(duration, () {
      if (mounted && !widget.isLocked) {
        widget.onTimeout();
      }
    });
  }

  @override
  void dispose() {
    InactivityGuard._activeStates.remove(this);
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollStartNotification ||
            notification is UserScrollNotification) {
          recordUserActivity();
        }
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => recordUserActivity(),
        onPointerMove: (_) => recordUserActivity(),
        onPointerHover: (_) => recordUserActivity(),
        onPointerSignal: (_) => recordUserActivity(),
        onPointerPanZoomStart: (_) => recordUserActivity(),
        onPointerPanZoomUpdate: (_) => recordUserActivity(),
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: (node, event) {
            recordUserActivity();
            return KeyEventResult.ignored;
          },
          child: widget.child,
        ),
      ),
    );
  }
}
