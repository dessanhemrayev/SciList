import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../data/models/journal.dart';
import 'level_badge.dart';
import '../../../../core/utils/date_formatter.dart';

class JournalCard extends StatelessWidget {
  final Journal journal;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final bool isFavorite;
  final bool showFavoriteButton;
  final int index;

  const JournalCard({
    super.key,
    required this.journal,
    this.onTap,
    this.onFavoriteToggle,
    this.isFavorite = false,
    this.showFavoriteButton = true,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            journal.primaryTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (journal.secondaryTitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              journal.secondaryTitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        LevelBadge(level: journal.latestLevel, size: 28),
                        if (showFavoriteButton) ...[
                          const SizedBox(height: 8),
                          IconButton(
                            onPressed: onFavoriteToggle,
                            icon: Icon(
                              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFavorite ? colorScheme.error : colorScheme.onSurfaceVariant,
                              size: 22,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.badge_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      journal.displayIssn,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (journal.dateAccepted != null) ...[
                      Icon(
                        Icons.event_available_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'с ${DateFormatter.format(journal.dateAccepted, short: true)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (!journal.isActive && journal.dateDiscontinued != null) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.event_busy_rounded,
                        size: 14,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'искл. ${DateFormatter.format(journal.dateDiscontinued, short: true)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1);
  }
}

class JournalHistoryCard extends StatelessWidget {
  final Journal journal;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final int index;

  const JournalHistoryCard({
    super.key,
    required this.journal,
    required this.onTap,
    required this.onDelete,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey(journal.primaryIssn),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_rounded,
          color: colorScheme.onErrorContainer,
          size: 28,
        ),
      ),
      confirmDismiss: (_) async => true,
      onDismissed: (_) => onDelete(),
      child: JournalCard(
        journal: journal,
        onTap: onTap,
        showFavoriteButton: false,
        index: index,
      ),
    );
  }
}