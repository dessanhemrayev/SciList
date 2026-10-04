import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/error_display.dart';
import '../widgets/journal/journal_detail_card.dart';
import '../widgets/journal/level_badge.dart';
import '../providers/journal_provider.dart';
import '../providers/history_provider.dart';
import '../providers/favorites_provider.dart';

class JournalDetailScreen extends StatefulWidget {
  final String issn;

  const JournalDetailScreen({super.key, required this.issn});

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  late final JournalProvider _journalProvider;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _journalProvider = context.read<JournalProvider>();
    _loadJournal();
  }

  Future<void> _loadJournal() async {
    if (!_hasLoaded) {
      _hasLoaded = true;
      await _journalProvider.fetchJournal(widget.issn);
      if (_journalProvider.hasJournal && mounted) {
        context.read<HistoryProvider>().addToHistory(_journalProvider.journal!);
      }
    }
  }

  Future<void> _refresh() async {
    _hasLoaded = false;
    await _loadJournal();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<JournalProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && !provider.hasJournal) {
            return CustomScrollView(
              slivers: [
                SliverCustomAppBar(
                  title: 'Журнал',
                  expandedHeight: 120,
                ),
                const SliverFillRemaining(
                  child: Center(child: LoadingIndicator(size: 50, message: 'Загрузка...')),
                ),
              ],
            );
          }

          if (provider.error != null && !provider.hasJournal) {
            return CustomScrollView(
              slivers: [
                SliverCustomAppBar(
                  title: 'Журнал',
                  expandedHeight: 120,
                ),
                SliverFillRemaining(
                  child: ErrorDisplay(
                    message: provider.error!,
                    onRetry: _refresh,
                  ),
                ),
              ],
            );
          }

          if (!provider.hasJournal) {
            return CustomScrollView(
              slivers: [
                SliverCustomAppBar(
                  title: 'Журнал',
                  expandedHeight: 120,
                ),
                const SliverFillRemaining(
                  child: Center(
                    child: ErrorDisplay(
                      message: 'Данные не загружены',
                      subtitle: 'Попробуйте обновить страницу',
                      icon: Icons.cloud_off_rounded,
                    ),
                  ),
                ),
              ],
            );
          }

          final journal = provider.journal!;
          final isFavorite = context.watch<FavoritesProvider>().isFavorite(journal.primaryIssn);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverCustomAppBar(
                  title: journal.primaryTitle.length > 30
                      ? '${journal.primaryTitle.substring(0, 30)}…'
                      : journal.primaryTitle,
                  expandedHeight: 140,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer.withValues(alpha: 0.5),
                            colorScheme.secondaryContainer.withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LevelBadge(
                              level: journal.latestLevel,
                              size: 48,
                              showLabel: true,
                            ).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut),
                            const SizedBox(height: 8),
                            Text(
                              journal.displayIssn,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ).animate().fadeIn(delay: 300.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () =>
                          context.read<FavoritesProvider>().toggleFavorite(journal),
                      icon: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? colorScheme.error : colorScheme.onSurface,
                      ),
                      tooltip: isFavorite ? 'Убрать из избранного' : 'В избранное',
                    ),
                    IconButton(
                      onPressed: _shareJournal,
                      icon: Icon(Icons.share_rounded, color: colorScheme.onSurface),
                      tooltip: 'Поделиться',
                    ),
                    if (journal.links?.main != null)
                      IconButton(
                        onPressed: () => _launchMainLink(journal.links!.main!),
                        icon: Icon(Icons.open_in_new_rounded, color: colorScheme.onSurface),
                        tooltip: 'Открыть сайт журнала',
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: JournalDetailCard(
                    journal: journal,
                    isFavorite: isFavorite,
                    onFavoriteToggle: () =>
                        context.read<FavoritesProvider>().toggleFavorite(journal),
                    onShare: _shareJournal,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _shareJournal() async {
    final provider = context.read<JournalProvider>();
    if (!provider.hasJournal) return;

    final journal = provider.journal!;
    
    final linkText = journal.links?.main != null 
        ? '\nСайт журнала: ${journal.links!.main}' 
        : '\nИсточник: journalrank.rcsi.science';

    final text = '''
${journal.primaryTitle}
${journal.secondaryTitle.isNotEmpty ? journal.secondaryTitle : ''}

ISSN: ${journal.displayIssn}
Уровень 2026: ${journal.level2026 ?? '—'}
Уровень 2025: ${journal.level2025 ?? '—'}
Уровень 2023: ${journal.level2023 ?? '—'}
$linkText
''';

    await Clipboard.setData(ClipboardData(text: text.trim()));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Текст скопирован в буфер обмена'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _launchMainLink(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Не удалось открыть ссылку'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}