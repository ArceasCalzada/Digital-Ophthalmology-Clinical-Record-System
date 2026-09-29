import 'dart:async';

import 'package:flutter/material.dart';

/// Calls [onTimeout] when nothing has touched the app for [timeout].
///
/// Any pointer activity (mouse, touch, stylus) restarts the countdown. Used to
/// sign users out of a workstation that was left open with patient data showing.
class InactivityGuard extends StatefulWidget {
  final Duration timeout;
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

  void _restart() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, () {
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
