import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared identity for the Jarvis AI assistant.
///
/// Jarvis is a "virtual" participant: it is not a real group member, but any
/// message it posts uses [jarvisEmail] as the sender so the chat UI can render
/// it with the Jarvis name and custom avatar.
class Jarvis {
  static const String jarvisEmail = 'jarvis@assistant.ai';
  static const String displayName = 'Jarvis';

  /// The trigger a user types in a chat to summon Jarvis, e.g.
  /// "@jarvis what's on the calendar?".
  static const String trigger = '@jarvis';

  static bool isJarvis(String? email) =>
      (email ?? '').toLowerCase() == jarvisEmail;

  /// Returns the question after an "@jarvis" mention, or null if the text
  /// isn't a Jarvis command.
  static String? extractQuestion(String text) {
    final trimmed = text.trim();
    if (trimmed.toLowerCase().startsWith(trigger)) {
      return trimmed.substring(trigger.length).trim();
    }
    return null;
  }
}

/// A custom-drawn AI assistant avatar — a glowing blue orb with an orbiting
/// accent and a gentle pulsing glow. No image asset, no third-party logo.
class JarvisAvatar extends StatefulWidget {
  final double radius;

  /// Whether the orb should pulse. Off for tiny static uses if desired.
  final bool animate;

  const JarvisAvatar({super.key, this.radius = 16, this.animate = true});

  @override
  State<JarvisAvatar> createState() => _JarvisAvatarState();
}

class _JarvisAvatarState extends State<JarvisAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // pulse 0..1 (eased). Static uses sit at mid-glow.
          final pulse = widget.animate
              ? Curves.easeInOut.transform(_controller.value)
              : 0.5;
          return CustomPaint(painter: _JarvisAvatarPainter(pulse));
        },
      ),
    );
  }
}

class _JarvisAvatarPainter extends CustomPainter {
  final double pulse; // 0..1
  _JarvisAvatarPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Background gradient disc (navy).
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF14294F), Color(0xFF060F24)],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Pulsing outer glow ring (brass), grows/brightens with pulse.
    final glowRing = Paint()
      ..color = const Color(0xFFE6C55A)
          .withValues(alpha: 0.30 + 0.45 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * (0.10 + 0.14 * pulse));
    canvas.drawCircle(center, r * 0.86, glowRing);

    // Crisp outer ring (brass).
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.10
      ..color = const Color(0xFFC9A227).withValues(alpha: 0.95);
    canvas.drawCircle(center, r * 0.82, ringPaint);

    // Core orb with a soft brass glow.
    final glowPaint = Paint()
      ..color = const Color(0xFFC9A227).withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25);
    canvas.drawCircle(center, r * (0.40 + 0.05 * pulse), glowPaint);

    final corePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF3E4A8), Color(0xFFC9A227)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.42));
    canvas.drawCircle(center, r * 0.40, corePaint);

    // Two orbiting dots on the ring.
    final dotPaint = Paint()..color = Colors.white;
    for (final angle in [-math.pi / 4, math.pi * 0.75]) {
      final dot = Offset(
        center.dx + r * 0.82 * math.cos(angle),
        center.dy + r * 0.82 * math.sin(angle),
      );
      canvas.drawCircle(dot, r * 0.10, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _JarvisAvatarPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
