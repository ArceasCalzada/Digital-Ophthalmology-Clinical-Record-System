import 'dart:async';

import 'package:flutter/material.dart';

/// Calls [onTimeout] when nothing has touched the app for [timeout].
///
/// Any pointer activity (mouse, touch, stylus) restarts the countdown. Used to
/// lock the workstation or sign users out when left open with patient data showing.
/// If [timeout] is null, auto-lock is disabled.
class InactivityGuard extends StatefulWidget {
  final Duration? timeout;
  final VoidCallback onTimeout;
  final Widget child;

  const InactivityGuard({
    super.key,
    required this.timeout,
    required this.onTimeout,
    required this.child,
  });

  @override
  State<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends State<InactivityGuard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(InactivityGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeout != widget.timeout) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    final duration = widget.timeout;
    if (duration == null) return;
    _timer = Timer(duration, () {
      if (mounted) widget.onTimeout();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      onPointerHover: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
