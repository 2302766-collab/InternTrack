import 'package:flutter/material.dart';

/// A reusable shell for auth screens that applies a gradient background,
/// centered card, and consistent spacing.
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
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFF0B4554),
              Color(0xFF146A7E),
              Color(0xFF1F90A7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -90,
                right: -40,
                child: _GlowOrb(
                  size: 240,
                  color: Colors.white.withAlpha(28),
                ),
              ),
              Positioned(
                bottom: -120,
                left: -30,
                child: _GlowOrb(
                  size: 280,
                  color: Colors.black.withAlpha(24),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 480;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 16 : 20,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FBFC),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withAlpha(145),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x3305232B),
                                blurRadius: 30,
                                offset: Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isNarrow ? 22 : 28,
                              vertical: isNarrow ? 24 : 30,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (onBack != null) ...[
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: onBack,
                                    tooltip: 'Back',
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFE7F1F4),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCEEF3),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF0F4C5C),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'InternTrack',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: const Color(0xFF0F4C5C),
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  title,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        color: const Color(0xFF0F4C5C),
                                        fontWeight: FontWeight.w800,
                                        height: 1.08,
                                      ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    subtitle!,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: const Color(0xFF57707A),
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                child,
                                if (footer != null) ...[
                                  const SizedBox(height: 18),
                                  const Divider(color: Color(0xFFD8E5E9)),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.center,
                                    child: footer!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
