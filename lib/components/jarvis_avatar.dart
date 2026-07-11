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

/// A custom-drawn AI assistant avatar — a glowing cyan/green orb with an
/// orbiting accent. No image asset, no third-party logo.
class JarvisAvatar extends StatelessWidget {
  final double radius;

  const JarvisAvatar({super.key, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _JarvisAvatarPainter()),
    );
  }
}

class _JarvisAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Background gradient disc.
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF0E7490), Color(0xFF0F172A)],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Outer ring.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.10
      ..color = const Color(0xFF8BFFB0).withValues(alpha: 0.85);
    canvas.drawCircle(center, r * 0.82, ringPaint);

    // Core orb with a soft glow.
    final glowPaint = Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25);
    canvas.drawCircle(center, r * 0.42, glowPaint);

    final corePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFA5F3FC), Color(0xFF34D399)],
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
