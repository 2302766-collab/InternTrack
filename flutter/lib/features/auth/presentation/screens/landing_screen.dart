import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const _surfaceBorder = Color(0x335CC7E6);
  static const _panelStart = Color(0xE61A3150);
  static const _panelEnd = Color(0xF0122238);
  static const _headline = Color(0xFFF2F8FF);
  static const _body = Color(0xFFB8C8DA);
  static const _accent = Color(0xFF8FE8FF);
  static const _success = Color(0xFF8CF1C9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF08131F), Color(0xFF102846), Color(0xFF0D1E33)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _LandingBackdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
                  final horizontalPadding = constraints.maxWidth >= 1200
                      ? 56.0
                      : constraints.maxWidth >= 720
                      ? 32.0
                      : 20.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      24,
                      horizontalPadding,
                      28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1220),
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: const [
                                  Expanded(flex: 6, child: _HeroSection()),
                                  SizedBox(width: 28),
                                  Expanded(flex: 5, child: _PreviewPanel()),
                                ],
                              )
                            : const Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _HeroSection(),
                                  SizedBox(height: 24),
                                  _PreviewPanel(),
                                ],
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

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: const [
            _BrandMark(),
            _StatusChip(
              icon: Icons.sync_alt_rounded,
              label: 'Student • Supervisor • Adviser',
            ),
          ],
        ),
        SizedBox(height: isMobile ? 28 : 34),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(24)),
          ),
          child: const Text(
            'Internship Monitoring System',
            style: TextStyle(
              color: LandingScreen._accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(height: isMobile ? 18 : 22),
        Text(
          'Track internship progress from first duty to final approval.',
          style: theme.textTheme.displaySmall?.copyWith(
            color: LandingScreen._headline,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -1.4,
            fontSize: isMobile ? 38 : 56,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            'InternTrack keeps student logbooks, daily time records, reports, and approvals in one guided workflow so everyone sees accurate progress in real time.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: LandingScreen._body,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : 210,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.login);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF88E2FF),
                  foregroundColor: const Color(0xFF072237),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Log In'),
              ),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 210,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.register);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withAlpha(30)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Colors.white.withAlpha(8),
                  textStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Create Account'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: const [
            _MetricChip(value: '24/7', label: 'Progress visibility'),
            _MetricChip(value: '1', label: 'Centralized workflow'),
            _MetricChip(value: 'Real-time', label: 'Review updates'),
          ],
        ),
        const SizedBox(height: 28),
        const Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _FeatureTile(
              icon: Icons.menu_book_rounded,
              title: 'Daily Logbook',
              description:
                  'Students write activities, attach proof, and keep records organized by date.',
            ),
            _FeatureTile(
              icon: Icons.schedule_rounded,
              title: 'DTR Monitoring',
              description:
                  'Track rendered hours and attendance without switching between separate files.',
            ),
            _FeatureTile(
              icon: Icons.verified_user_rounded,
              title: 'Faster Review',
              description:
                  'Supervisors and advisers can review submissions and confirm progress in one place.',
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: LandingScreen._surfaceBorder),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [LandingScreen._panelStart, LandingScreen._panelEnd],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(65),
                blurRadius: 40,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8DE8FF), Color(0xFF3FA9D9)],
                      ),
                    ),
                    child: const Icon(
                      Icons.space_dashboard_rounded,
                      color: Color(0xFF07243A),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Internship overview',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: LandingScreen._headline,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Responsive from mobile cards to desktop dashboard previews.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: LandingScreen._body,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _ProgressPreview(),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 420;
                  return stacked
                      ? const Column(
                          children: [
                            _MiniPanel(
                              title: 'Pending Reviews',
                              value: '08',
                              helper: 'Supervisor queue',
                              icon: Icons.rate_review_rounded,
                              accent: Color(0xFFFFC56E),
                            ),
                            SizedBox(height: 14),
                            _MiniPanel(
                              title: 'Hours Logged',
                              value: '320',
                              helper: 'Current internship total',
                              icon: Icons.access_time_filled_rounded,
                              accent: LandingScreen._success,
                            ),
                          ],
                        )
                      : const Row(
                          children: [
                            Expanded(
                              child: _MiniPanel(
                                title: 'Pending Reviews',
                                value: '08',
                                helper: 'Supervisor queue',
                                icon: Icons.rate_review_rounded,
                                accent: Color(0xFFFFC56E),
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: _MiniPanel(
                                title: 'Hours Logged',
                                value: '320',
                                helper: 'Current internship total',
                                icon: Icons.access_time_filled_rounded,
                                accent: LandingScreen._success,
                              ),
                            ),
                          ],
                        );
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withAlpha(16)),
                ),
                child: const Column(
                  children: [
                    _TimelineRow(
                      title: 'Submit weekly log',
                      subtitle: 'Student activity report',
                      status: 'Synced',
                    ),
                    SizedBox(height: 12),
                    _TimelineRow(
                      title: 'Review by supervisor',
                      subtitle: 'Comment and verify entries',
                      status: 'In queue',
                    ),
                    SizedBox(height: 12),
                    _TimelineRow(
                      title: 'Generate report',
                      subtitle: 'Ready for adviser checking',
                      status: 'Ready',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(16)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business_center_rounded, color: LandingScreen._accent),
          SizedBox(width: 10),
          Text(
            'InternTrack',
            style: TextStyle(
              color: LandingScreen._headline,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: LandingScreen._success),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: LandingScreen._body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: LandingScreen._headline,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: LandingScreen._body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.brandBlue.withAlpha(60),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: LandingScreen._accent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: LandingScreen._headline,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: LandingScreen._body,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressPreview extends StatelessWidget {
  const _ProgressPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2238).withAlpha(205),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withAlpha(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Internship Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: LandingScreen._headline,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Text(
                '80%',
                style: TextStyle(
                  color: LandingScreen._accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: 0.8,
              backgroundColor: Colors.white.withAlpha(10),
              valueColor: const AlwaysStoppedAnimation<Color>(
                LandingScreen._accent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: _StageBadge(label: 'Orientation', active: true)),
              SizedBox(width: 10),
              Expanded(child: _StageBadge(label: 'Logbook', active: true)),
              SizedBox(width: 10),
              Expanded(child: _StageBadge(label: 'Evaluation', active: false)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? LandingScreen._accent.withAlpha(28)
            : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? LandingScreen._accent.withAlpha(70)
              : Colors.white.withAlpha(14),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? LandingScreen._headline : LandingScreen._body,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniPanel extends StatelessWidget {
  const _MiniPanel({
    required this.title,
    required this.value,
    required this.helper,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: LandingScreen._body,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: LandingScreen._headline,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: const TextStyle(
              color: LandingScreen._body,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: LandingScreen._accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: LandingScreen._headline,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: LandingScreen._body,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status,
            style: const TextStyle(
              color: LandingScreen._accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LandingBackdrop extends StatelessWidget {
  const _LandingBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -40,
          child: _GlowBlob(
            width: 320,
            height: 320,
            color: const Color(0xFF57C9FF).withAlpha(50),
          ),
        ),
        Positioned(
          right: -90,
          top: 90,
          child: _GlowBlob(
            width: 280,
            height: 280,
            color: const Color(0xFF93F1D2).withAlpha(38),
          ),
        ),
        Positioned(
          bottom: -80,
          left: 80,
          child: _GlowBlob(
            width: 260,
            height: 260,
            color: const Color(0xFF2E79FF).withAlpha(34),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(
              lineColor: const Color(0xFFD5F1FF).withAlpha(10),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    const gap = 34.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}
