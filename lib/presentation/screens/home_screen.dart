import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/error_display.dart';
import '../widgets/journal/issn_input_field.dart';
import '../widgets/journal/journal_card.dart';
import '../widgets/layout/animated_background.dart';
import '../widgets/layout/section_header.dart';
import '../providers/journal_provider.dart';
import '../providers/history_provider.dart';
import '../providers/favorites_provider.dart';
import '../../data/models/journal.dart';
import '../../core/utils/issn_validator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _issnController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _issnController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    if (_formKey.currentState?.validate() ?? false) {
      final issn = IssnValidator.format(_issnController.text);
      final provider = context.read<JournalProvider>();
      await provider.fetchJournal(issn);
      if (provider.hasJournal && mounted) {
        context.read<HistoryProvider>().addToHistory(provider.journal!);
      }
      _focusNode.unfocus();
    }
  }

  void _onHistoryItemTap(Journal journal) {
    context.push('/journal/${journal.primaryIssn}');
  }

  void _onHistoryItemDelete(Journal journal) {
    context.read<HistoryProvider>().removeFromHistory(journal.primaryIssn);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'SciList',
          actions: [
            IconButton(
              icon: Icon(Icons.favorite_border_rounded, color: colorScheme.onSurface),
              onPressed: () => context.push('/favorites'),
              tooltip: 'Избранное',
            ),
            IconButton(
              icon: Icon(Icons.history_rounded, color: colorScheme.onSurface),
              onPressed: () => context.push('/history'),
              tooltip: 'История',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 32),
                  _buildSearchSection(),
                  const SizedBox(height: 24),
                  _buildResultSection(),
                  const SizedBox(height: 24),
                  _buildHistorySection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.science_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 12),
              Text(
                'Белый список научных журналов',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                'Поиск по ISSN в базе РЦНИ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Введите ISSN журнала (формат XXXX-XXXX) для получения информации об уровне в Белом списке РЦНИ за 2023, 2025 и 2026 годы.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Consumer<JournalProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IssnInputField(
              controller: _issnController,
              focusNode: _focusNode,
              onSubmitted: _handleSearch,
              autofocus: true,
              onChanged: (value) {
                if (value.isEmpty) {
                  context.read<JournalProvider>().clear();
                }
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: provider.isLoading ? null : _handleSearch,
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(provider.isLoading ? 'Поиск...' : 'Найти журнал'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ).animate().fadeIn(delay: 100.ms).scale(),
          ],
        );
      },
    );
  }

  Widget _buildResultSection() {
    return Consumer<JournalProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: LoadingIndicator(size: 50, message: 'Загрузка данных журнала...'),
            ),
          ).animate().fadeIn();
        }

        if (provider.error != null) {
          return ErrorDisplay(
            message: provider.error!,
            onRetry: provider.lastQueriedIssn != null
                ? () => provider.fetchJournal(provider.lastQueriedIssn!)
                : null,
          ).animate().fadeIn();
        }

        if (provider.hasJournal) {
          final journal = provider.journal!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Результат поиска',
                subtitle: 'Журнал найден в базе',
                trailing: IconButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/journal/${journal.primaryIssn}'),
                  icon: const Icon(Icons.open_in_new_rounded),
                  tooltip: 'Открыть детали',
                ),
              ),
              JournalCard(
                journal: journal,
                onTap: () => Navigator.of(context)
                    .pushNamed('/journal/${journal.primaryIssn}'),
                onFavoriteToggle: () =>
                    context.read<FavoritesProvider>().toggleFavorite(journal),
                isFavorite: context.watch<FavoritesProvider>().isFavorite(journal.primaryIssn),
                index: 0,
              ),
            ],
          ).animate().fadeIn().slideY(begin: 0.1);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHistorySection() {
    return Consumer<HistoryProvider>(
      builder: (context, provider, _) {
        if (provider.isEmpty) return const SizedBox.shrink();

        final recentItems = provider.history.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Недавние поиски',
              subtitle: '${provider.length} в истории',
              trailing: TextButton(
                onPressed: () => context.push('/history'),
                child: const Text('Все'),
              ),
            ),
            SizedBox(
              height: 165, // Увеличили высоту со 140 до 176, чтобы вместить текст при увеличенном шрифте
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recentItems.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final journal = recentItems[index];
                  return SizedBox(
                    width: 280,
                    child: JournalCard(
                      journal: journal,
                      onTap: () => _onHistoryItemTap(journal),
                      onFavoriteToggle: () =>
                          context.read<FavoritesProvider>().toggleFavorite(journal),
                      isFavorite: context.watch<FavoritesProvider>().isFavorite(journal.primaryIssn),
                      showFavoriteButton: true,
                      index: index,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}