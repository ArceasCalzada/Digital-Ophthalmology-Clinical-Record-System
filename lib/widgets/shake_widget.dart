import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps a form field and wiggles it sideways when [ShakeWidgetState.shake] is
/// called. Used instead of printing "Required" under a field: the field that still
/// needs attention shakes, and stays outlined in red until it is filled in.
class ShakeWidget extends StatefulWidget {
  final Widget child;

  const ShakeWidget({super.key, required this.child});

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  static const double _distance = 8;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// Plays the shake from the start (again, if it is already running).
  void shake() {
    if (mounted) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Three full swings that fade out.
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 6) * _distance * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
