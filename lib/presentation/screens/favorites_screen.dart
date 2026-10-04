import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/journal/journal_card.dart';
import '../providers/favorites_provider.dart';
import '../../data/models/journal.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: CustomAppBar(
            title: 'Избранное',
            actions: [
              if (!provider.isEmpty) ...[
                IconButton(
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                  tooltip: _isGridView ? 'Список' : 'Сетка',
                ),
                IconButton(
                  onPressed: () => _showClearDialog(context, provider),
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: 'Очистить избранное',
                ),
              ],
            ],
          ),
          body: provider.isEmpty
              ? EmptyState(
                  title: 'Избранное пусто',
                  subtitle: 'Добавьте журналы в избранное,\nнажимая на сердечко в карточке',
                  icon: Icons.favorite_border_rounded,
                )
              : _isGridView
                  ? _buildGridView(provider)
                  : _buildListView(provider),
        );
      },
    );
  }

  Widget _buildListView(FavoritesProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.favorites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final journal = provider.favorites[index];
        return JournalCard(
          journal: journal,
          onTap: () => context.push('/journal/${journal.primaryIssn}'),
          onFavoriteToggle: () => provider.toggleFavorite(journal),
          isFavorite: true,
          index: index,
        ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1);
      },
    );
  }

  Widget _buildGridView(FavoritesProvider provider) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: provider.favorites.length,
      itemBuilder: (context, index) {
        final journal = provider.favorites[index];
        return _FavoriteGridCard(
          journal: journal,
          onTap: () => context.push('/journal/${journal.primaryIssn}'),
          onRemove: () => provider.removeFavorite(journal.primaryIssn),
        ).animate().fadeIn(delay: (50 * index).ms).scale();
      },
    );
  }

  void _showClearDialog(BuildContext context, FavoritesProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить избранное?'),
        content: const Text('Все сохранённые журналы будут удалены из избранного.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              provider.clearFavorites();
              Navigator.of(context).pop();
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }
}

class _FavoriteGridCard extends StatelessWidget {
  final Journal journal;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteGridCard({
    required this.journal,
    required this.onTap,
    required this.onRemove,
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
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            journal.primaryTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (journal.secondaryTitle.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              journal.secondaryTitle,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      journal.displayIssn,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _MiniLevelBadge(level: journal.latestLevel),
                        const Spacer(),
                        Icon(
                          Icons.favorite_rounded,
                          color: colorScheme.error,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniLevelBadge extends StatelessWidget {
  final int? level;

  const _MiniLevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    if (level == null) return const SizedBox.shrink();

    final config = _LevelConfig.get(level!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Ур. $level',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: config.color,
        ),
      ),
    );
  }
}

class _LevelConfig {
  final Color color;
  final String label;

  const _LevelConfig(this.color, this.label);

  static _LevelConfig get(int level) {
    switch (level) {
      case 1:
        return const _LevelConfig(Color(0xFFEF4444), 'I');
      case 2:
        return const _LevelConfig(Color(0xFFF97316), 'II');
      case 3:
        return const _LevelConfig(Color(0xFF3B82F6), 'III');
      case 4:
        return const _LevelConfig(Color(0xFF22C55E), 'IV');
      default:
        return const _LevelConfig(Color(0xFF64748B), '?');
    }
  }
}