import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LevelBadge extends StatelessWidget {
  final int? level;
  final double size;
  final bool showLabel;

  const LevelBadge({
    super.key,
    required this.level,
    this.size = 32,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    if (level == null) {
      return const _UnknownLevelBadge();
    }

    final config = LevelConfig.get(level!);
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.35, vertical: size * 0.1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.color.withValues(alpha: 0.9),
            config.color,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.4),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${level!}',
            style: TextStyle(
              fontSize: size * 0.65,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              config.label,
              style: TextStyle(
                fontSize: size * 0.45,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
                height: 1,
              ),
            ),
          ],
        ],
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.elasticOut);
  }
}

class _UnknownLevelBadge extends StatelessWidget {
  const _UnknownLevelBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Text(
        '—',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class LevelConfig {
  final Color color;
  final String label;

  const LevelConfig(this.color, this.label);

  static LevelConfig get(int level) {
    switch (level) {
      case 1:
        return const LevelConfig(Color(0xFFEF4444), 'I');
      case 2:
        return const LevelConfig(Color(0xFFF97316), 'II');
      case 3:
        return const LevelConfig(Color(0xFF3B82F6), 'III');
      case 4:
        return const LevelConfig(Color(0xFF22C55E), 'IV');
      default:
        return const LevelConfig(Color(0xFF64748B), '?');
    }
  }

  static Color getColor(int level) => get(level).color;
  static String getLabel(int level) => get(level).label;
}

class LevelIndicator extends StatelessWidget {
  final int? level;
  final double size;

  const LevelIndicator({
    super.key,
    required this.level,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (level == null) return const SizedBox.shrink();

    final config = LevelConfig.get(level!);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: config.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$level',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.elasticOut);
  }
}

class LevelChip extends StatelessWidget {
  final int? level;
  final String? yearLabel;

  const LevelChip({
    super.key,
    required this.level,
    this.yearLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (level == null) return const SizedBox.shrink();

    final config = LevelConfig.get(level!);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: config.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (yearLabel != null) ...[
            Text(
              yearLabel!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: config.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: config.color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Уровень $level',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }
}
