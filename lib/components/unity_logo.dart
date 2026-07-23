import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:login_ui/theme/app_theme.dart';

/// The "Unity" brand mark: three brass shards that interlock into a single
/// rounded triangle — symbolizing separate people/clubs coming together.
///
/// [assembly] 0..1 controls how assembled the mark is:
///   0 = shards scattered/exploded outward and faded,
///   1 = fully assembled, tight logo.
/// Use values > 1 conceptually by driving the reveal (see UnityRevealOverlay).
class UnityLogo extends StatelessWidget {
  final double size;

  /// 1 = assembled. As it goes 1 -> 0 (or beyond via [explode]) the shards
  /// separate. [explode] pushes shards further out for the reveal.
  final double assembly;

  /// Extra outward push (0 = none). Used by the split reveal to fling shards
  /// off-screen while fading.
  final double explode;

  const UnityLogo({
    super.key,
    this.size = 120,
    this.assembly = 1,
    this.explode = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _UnityPainter(assembly: assembly, explode: explode),
      ),
    );
  }
}

class _UnityPainter extends CustomPainter {
  final double assembly; // 0..1
  final double explode; // 0..N

  _UnityPainter({required this.assembly, required this.explode});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.36;

    // Three shards arranged around the center, pointing outward at 120° apart.
    // Each shard is a rounded triangle wedge; when assembled they meet at center.
    const shardColors = [
      AppColors.brass,
      AppColors.brassLight,
      AppColors.brassDeep,
    ];

    for (int i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / 3); // start at top
      // Separation distance: 0 when assembled, grows as assembly drops or on explode.
      final sep = (1 - assembly) * r * 1.4 + explode * size.width;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final shardCenter = center + dir * (r * 0.42 + sep);

      // Fade shards out as they explode away.
      final fade = (1.0 - explode).clamp(0.0, 1.0);
      final opacity = (0.35 + 0.65 * assembly) * fade;

      final paint = Paint()
        ..color = shardColors[i].withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // Build a wedge shard as a path, rotated to point outward.
      final path = _shardPath(shardCenter, r, angle);
      canvas.drawPath(path, paint);
    }

    // Central "core" dot that binds them, brightest when assembled.
    final core = Paint()
      ..color = Colors.white.withValues(
        alpha: (assembly * (1 - explode)).clamp(0.0, 1.0),
      );
    if (assembly > 0.6 && explode < 0.5) {
      canvas.drawCircle(center, r * 0.14 * assembly, core);
    }
  }

  /// A rounded triangular shard centered at [c], pointing along [angle].
  Path _shardPath(Offset c, double r, double angle) {
    final size = r * 0.95;
    // Local shard: an isosceles triangle pointing "up" (toward center),
    // then rotate by angle+90° so its tip faces the middle.
    final tip = Offset(0, -size * 0.55);
    final baseL = Offset(-size * 0.5, size * 0.45);
    final baseR = Offset(size * 0.5, size * 0.45);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(baseR.dx, baseR.dy)
      ..lineTo(baseL.dx, baseL.dy)
      ..close();

    final matrix = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(angle + math.pi / 2);
    return path.transform(matrix.storage);
  }

  @override
  bool shouldRepaint(covariant _UnityPainter oldDelegate) =>
      oldDelegate.assembly != assembly || oldDelegate.explode != explode;
}

/// The animated Unity loading mark (no Scaffold/background) — shards assemble,
/// then gently drift + pulse. Drop it wherever a spinner would go for a
/// full-view loading state (it centers itself).
class UnityLoadingIndicator extends StatefulWidget {
  final double size;
  const UnityLoadingIndicator({super.key, this.size = 120});

  @override
  State<UnityLoadingIndicator> createState() => _UnityLoadingIndicatorState();
}

class _UnityLoadingIndicatorState extends State<UnityLoadingIndicator>
    with TickerProviderStateMixin {
  // Assembles the shards once (0 -> 1), then holds.
  late final AnimationController _assemble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  // Continuous slow rotation + breathing pulse.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _assemble.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_assemble, _idle]),
        builder: (context, _) {
          final a = Curves.easeOutBack.transform(_assemble.value.clamp(0, 1));
          final pulse = 1 + 0.05 * math.sin(_idle.value * 2 * math.pi);
          final rotate = _idle.value * 2 * math.pi;
          return Transform.rotate(
            angle: rotate * 0.15, // subtle drift
            child: Transform.scale(
              scale: pulse,
              child: UnityLogo(
                size: widget.size,
                assembly: a.clamp(0.0, 1.0),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Full-screen loading screen: the Unity mark on the app wallpaper. Use for
/// whole-page loading states (its own Scaffold + background).
class UnityLoadingScreen extends StatelessWidget {
  const UnityLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: NeonBackground(
        child: UnityLoadingIndicator(size: 140),
      ),
    );
  }
}

/// Plays once after login: shows the assembled Unity logo, holds a beat, then
/// splits the shards apart to reveal [child] (the app) fading in behind.
class UnityRevealOverlay extends StatefulWidget {
  final Widget child;
  const UnityRevealOverlay({super.key, required this.child});

  @override
  State<UnityRevealOverlay> createState() => _UnityRevealOverlayState();
}

class _UnityRevealOverlayState extends State<UnityRevealOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Once finished, drop the overlay entirely so the app is fully interactive.
    if (_done) return widget.child;

    return Stack(
      children: [
        // The app fades/scales in behind the logo.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // App starts hidden, fades in during the second half (the split).
            final t = _controller.value;
            final appOpacity = Curves.easeIn.transform(
              ((t - 0.45) / 0.55).clamp(0.0, 1.0),
            );
            final appScale = 0.92 + 0.08 * appOpacity;
            return Opacity(
              opacity: appOpacity,
              child: Transform.scale(scale: appScale, child: child),
            );
          },
          child: widget.child,
        ),
        // The Unity logo overlay: holds, then splits apart + fades.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            // Phase 1 (0..0.45): logo sits assembled, gently pulsing.
            // Phase 2 (0.45..1): shards explode outward and fade.
            final explode = t < 0.45
                ? 0.0
                : Curves.easeInCubic.transform((t - 0.45) / 0.55);
            final pulse = t < 0.45 ? 1 + 0.04 * math.sin(t * 12) : 1.0;

            return IgnorePointer(
              ignoring: t > 0.45,
              child: Container(
                // Solid navy backdrop that itself fades as the split completes.
                color: AppColors.navy.withValues(
                  alpha: (1 - (explode * 1.4)).clamp(0.0, 1.0),
                ),
                child: Center(
                  child: Transform.scale(
                    scale: pulse.toDouble(),
                    child: UnityLogo(
                      size: 160,
                      assembly: 1,
                      explode: explode,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
