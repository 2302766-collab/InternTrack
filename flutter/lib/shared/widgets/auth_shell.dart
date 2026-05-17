import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared auth layout inspired by a dark glassmorphism card.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.footer,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.9),
            radius: 1.35,
            colors: [Color(0xFF1D446B), Color(0xFF11253D), Color(0xFF091525)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _BackdropTexture()),
            Positioned(
              top: -100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 260,
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8FD8FF).withAlpha(140),
                        const Color(0xFF8FD8FF).withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 120,
              right: 110,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withAlpha(0),
                        const Color(0xFF99E6FF).withAlpha(220),
                        Colors.white.withAlpha(0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8ADFFF).withAlpha(120),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 18 : 24,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(
                              color: const Color(0xFF76D8FF).withAlpha(90),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF27496D).withAlpha(165),
                                const Color(0xFF172A43).withAlpha(210),
                                const Color(0xFF121F35).withAlpha(230),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(75),
                                blurRadius: 40,
                                offset: const Offset(0, 30),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(36),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withAlpha(20),
                                          Colors.white.withAlpha(5),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _NoisePainter(
                                      color: Colors.white.withAlpha(16),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    isNarrow ? 22 : 38,
                                    isNarrow ? 28 : 34,
                                    isNarrow ? 22 : 38,
                                    isNarrow ? 24 : 30,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (onBack != null)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 18,
                                            ),
                                            child: IconButton(
                                              onPressed: onBack,
                                              tooltip: 'Back',
                                              style: IconButton.styleFrom(
                                                backgroundColor: Colors.white
                                                    .withAlpha(18),
                                                foregroundColor: Colors.white
                                                    .withAlpha(220),
                                                side: BorderSide(
                                                  color: Colors.white.withAlpha(
                                                    28,
                                                  ),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.arrow_back_rounded,
                                              ),
                                            ),
                                          ),
                                        ),
                                      const _AuthOrbLogo(),
                                      const SizedBox(height: 26),
                                      Text(
                                        title,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                              color: const Color(0xFFEAF4FF),
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.8,
                                            ),
                                      ),
                                      if (subtitle != null) ...[
                                        const SizedBox(height: 10),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 360,
                                          ),
                                          child: Text(
                                            subtitle!,
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  color: const Color(
                                                    0xFFA8B8CC,
                                                  ),
                                                  height: 1.45,
                                                ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 30),
                                      child,
                                      if (footer != null) ...[
                                        const SizedBox(height: 22),
                                        footer!,
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthOrbLogo extends StatelessWidget {
  const _AuthOrbLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withAlpha(32), Colors.white.withAlpha(10)],
        ),
        border: Border.all(color: Colors.white.withAlpha(30)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8FDAFF).withAlpha(65),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(235), width: 2.3),
          ),
          child: Align(
            alignment: const Alignment(0.9, 0),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1C3452),
                border: Border.all(
                  color: Colors.white.withAlpha(185),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackdropTexture extends StatelessWidget {
  const _BackdropTexture();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9AC7E5).withAlpha(10)
      ..strokeWidth = 1;

    const gap = 28.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NoisePainter extends CustomPainter {
  const _NoisePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final random = math.Random(24);

    for (int i = 0; i < 900; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(dx, dy), 0.55, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
