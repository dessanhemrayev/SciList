import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/update_provider.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/update/update_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Настройки'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Consumer<UpdateProvider>(
            builder: (context, provider, _) {
              final version = provider.currentVersion;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SciList',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            version == null ? 'Версия: ...' : 'Версия: $version',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Обновления', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Consumer<UpdateProvider>(
            builder: (context, provider, _) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: ListTile(
                  leading: Icon(Icons.system_update_alt_rounded, color: colorScheme.primary),
                  title: const Text('Проверить обновления'),
                  subtitle: Text(
                    provider.lastCheckAt == null
                        ? 'Обновление проверяется автоматически раз в '
                              '${UpdateProvider.checkInterval.inHours} ч'
                        : 'Последняя проверка: ${_formatLastCheck(provider.lastCheckAt!)}',
                  ),
                  trailing: provider.isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: provider.isChecking ? null : () => _checkForUpdates(context),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final provider = context.read<UpdateProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await provider.checkForUpdates(force: true);

    if (!context.mounted) return;

    switch (result) {
      case UpdateCheckResult.updateAvailable:
        final update = provider.availableUpdate!;
        await presentUpdateDialog(context, update);
      case UpdateCheckResult.upToDate:
        messenger.showSnackBar(
          const SnackBar(content: Text('У вас последняя версия')),
        );
      case UpdateCheckResult.failed:
        messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось проверить обновления')),
        );
    }
  }

  String _formatLastCheck(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final time = '${two(local.hour)}:${two(local.minute)}';
    if (isToday) return 'сегодня в $time';
    return '${two(local.day)}.${two(local.month)} в $time';
  }
}