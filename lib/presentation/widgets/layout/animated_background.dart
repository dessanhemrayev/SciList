import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final Duration animationDuration;

  const AnimatedBackground({
    super.key,
    required this.child,
    this.colors,
    this.animationDuration = const Duration(seconds: 8),
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = widget.colors ??
        [
          colorScheme.primary.withValues(alpha: 0.08),
          colorScheme.secondary.withValues(alpha: 0.08),
          colorScheme.tertiary.withValues(alpha: 0.08),
        ];

    return Stack(
      children: [
        Container(color: colorScheme.surface),
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = (_controller.value + index * 0.33) % 1.0;
              final size = MediaQuery.of(context).size;
              final radius = size.shortestSide * 0.6;

              return Positioned(
                left: (size.width - radius) / 2 +
                    (size.width * 0.3 * (index.isEven ? 1 : -1)) *
                        (progress - 0.5) *
                        2,
                top: (size.height - radius) / 2 +
                    (size.height * 0.2 * (index % 3 - 1)) *
                        (progress - 0.5) *
                        2,
                child: Container(
                  width: radius,
                  height: radius,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors[index % colors.length].withValues(alpha: 0.5),
                        colors[index % colors.length].withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
        widget.child,
      ],
    );
  }
}

class GradientMeshBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;

  const GradientMeshBackground({
    super.key,
    required this.child,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colorsList = colors ??
        [
          colorScheme.primary.withValues(alpha: 0.12),
          colorScheme.secondary.withValues(alpha: 0.1),
          colorScheme.tertiary.withValues(alpha: 0.08),
        ];

    return Stack(
      children: [
        Container(color: colorScheme.surface),
        CustomPaint(
          painter: _MeshPainter(colors: colorsList),
          size: Size.infinite,
        ),
        child,
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  final List<Color> colors;

  _MeshPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < colors.length; i++) {
      final color = colors[i];
      final centerX = size.width * (0.2 + i * 0.3);
      final centerY = size.height * (0.15 + i * 0.35);
      final radius = size.shortestSide * 0.45;

      paint.color = color;
      paint.shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: radius));

      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SubtlePatternBackground extends StatelessWidget {
  final Widget child;
  final Color? patternColor;

  const SubtlePatternBackground({
    super.key,
    required this.child,
    this.patternColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final patternCol = patternColor ?? colorScheme.onSurface.withValues(alpha: 0.02);

    return Stack(
      children: [
        Container(color: colorScheme.surface),
        CustomPaint(
          painter: _PatternPainter(color: patternCol),
          size: Size.infinite,
        ),
        child,
      ],
    );
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    final path = Path();

    for (double x = 0; x <= size.width; x += spacing) {
      path.moveTo(x, 0);
      path.lineTo(x, size.height);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      path.moveTo(0, y);
      path.lineTo(size.width, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}