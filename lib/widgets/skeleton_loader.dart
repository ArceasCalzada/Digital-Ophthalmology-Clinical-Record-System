import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated shimmer wrapper that provides a sliding gradient effect across children.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBase = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final defaultHighlight = isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC);

    final base = widget.baseColor == const Color(0xFFE2E8F0) ? defaultBase : widget.baseColor;
    final highlight = widget.highlightColor == const Color(0xFFF8FAFC) ? defaultHighlight : widget.highlightColor;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                base,
                highlight,
                base,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: _animation.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Basic rectangular skeleton placeholder with customizable width, height, and border radius.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color? color;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = color ?? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Circular skeleton placeholder ideal for avatars and icons.
class SkeletonAvatar extends StatelessWidget {
  final double radius;

  const SkeletonAvatar({
    super.key,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: radius * 2,
      height: radius * 2,
      borderRadius: radius,
    );
  }
}

/// Skeleton loader matching the grid patient card layout in Patient Directory.
class SkeletonPatientCard extends StatelessWidget {
  const SkeletonPatientCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Card(
        color: AppTheme.cardBg,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonAvatar(radius: 20),
                  SkeletonBox(width: 80, height: 22, borderRadius: 12),
                ],
              ),
              const SizedBox(height: 14),
              const SkeletonBox(width: 160, height: 18, borderRadius: 4),
              const SizedBox(height: 8),
              const SkeletonBox(width: 200, height: 14, borderRadius: 4),
              const SizedBox(height: 8),
              const SkeletonBox(width: 120, height: 12, borderRadius: 4),
              const Spacer(),
              Divider(height: 1, color: AppTheme.borderColor),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: SkeletonBox(height: 36, borderRadius: 8)),
                  SizedBox(width: 8),
                  Expanded(child: SkeletonBox(height: 36, borderRadius: 8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader matching a row in the Patient Directory table view.
class SkeletonTableRow extends StatelessWidget {
  const SkeletonTableRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: const [
            SkeletonAvatar(radius: 18),
            SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 16, borderRadius: 4),
                  SizedBox(height: 6),
                  SkeletonBox(width: 90, height: 12, borderRadius: 4),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: SkeletonBox(width: 80, height: 14, borderRadius: 4),
            ),
            SizedBox(width: 16),
            Expanded(
              child: SkeletonBox(width: 100, height: 14, borderRadius: 4),
            ),
            SizedBox(width: 16),
            SkeletonBox(width: 70, height: 32, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader matching a workspace card in the Teams workspace.
class SkeletonTeamCard extends StatelessWidget {
  const SkeletonTeamCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.lightBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: const [
            SkeletonAvatar(radius: 14),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 16, borderRadius: 4),
                  SizedBox(height: 6),
                  SkeletonBox(width: 110, height: 12, borderRadius: 4),
                ],
              ),
            ),
            SkeletonBox(width: 76, height: 32, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader matching a member or pending approval tile in Teams & Collaboration.
class SkeletonMemberTile extends StatelessWidget {
  const SkeletonMemberTile({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: const [
            SkeletonAvatar(radius: 18),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 130, height: 15, borderRadius: 4),
                  SizedBox(height: 6),
                  SkeletonBox(width: 160, height: 12, borderRadius: 4),
                ],
              ),
            ),
            SkeletonBox(width: 70, height: 24, borderRadius: 12),
            SizedBox(width: 8),
            SkeletonBox(width: 32, height: 32, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}
