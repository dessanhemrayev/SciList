import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/push_provider.dart';
import '../providers/update_provider.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/update/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Разрешение на уведомления могли отозвать в системных настройках —
    // иначе переключатель врал бы, что уведомления включены
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PushProvider>().refreshPermission(),
    );
  }

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
          const SizedBox(height: 12),
          Consumer<PushProvider>(
            builder: (context, provider, _) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_active_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Уведомлять об обновлениях'),
                  subtitle: Text(_pushSubtitle(provider)),
                  value: provider.isActive,
                  onChanged: provider.isBusy || !provider.isAvailable
                      ? null
                      : (value) => _setPushEnabled(context, provider, value),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _pushSubtitle(PushProvider provider) {
    if (!provider.isAvailable) {
      return 'Push-уведомления на этом устройстве недоступны';
    }
    if (provider.isActive) {
      return 'Придёт уведомление, когда выйдет новый релиз';
    }
    return 'При включении спросим разрешение на уведомления';
  }

  Future<void> _setPushEnabled(
    BuildContext context,
    PushProvider provider,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await provider.setEnabled(value);

    if (!context.mounted) return;

    switch (result) {
      case PushToggleResult.updated:
        break;
      case PushToggleResult.permissionDenied:
        messenger.showSnackBar(
          const SnackBar(content: Text('Без разрешения уведомления показать нечем')),
        );
      case PushToggleResult.unavailable:
        messenger.showSnackBar(
          const SnackBar(content: Text('Push-уведомления недоступны на этом устройстве')),
        );
    }
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