import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/journal/journal_card.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: CustomAppBar(
            title: 'История поисков',
            actions: [
              if (!provider.isEmpty)
                IconButton(
                  onPressed: () => _showClearDialog(context, provider),
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: 'Очистить историю',
                ),
            ],
          ),
          body: provider.isEmpty
              ? EmptyState(
                  title: 'История пуста',
                  subtitle: 'Ваши поиски по ISSN появятся здесь',
                  icon: Icons.history_rounded,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.history.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final journal = provider.history[index];
                    return JournalHistoryCard(
                      journal: journal,
                      onTap: () => context.push('/journal/${journal.primaryIssn}'),
                      onDelete: () =>
                          provider.removeFromHistory(journal.primaryIssn),
                      index: index,
                    );
                  },
                ),
        );
      },
    );
  }

  void _showClearDialog(BuildContext context, HistoryProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все записи поиска будут удалены безвозвратно.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              provider.clearHistory();
              context.pop();
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }
}