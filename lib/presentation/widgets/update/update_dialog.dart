import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/update_info.dart';
import '../../providers/update_provider.dart';

enum UpdateDialogAction { update, later, skip }

/// Показывает диалог и выполняет действие: скачать APK, пропустить версию
/// или ничего не делать. Вызывать после первого кадра.
Future<void> presentUpdateDialog(BuildContext context, UpdateInfo update) async {
  final provider = context.read<UpdateProvider>();
  final action = await showUpdateDialog(context, update);
  if (action == null) return;

  switch (action) {
    case UpdateDialogAction.skip:
      await provider.skipVersion(update.version);
    case UpdateDialogAction.update:
      final opened = await provider.openDownload(update);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку на загрузку')),
        );
      }
    case UpdateDialogAction.later:
      return;
  }
}

/// Диалог «Доступна версия X.Y.Z». Вызывать только после первого кадра,
/// когда Navigator уже построен.
Future<UpdateDialogAction?> showUpdateDialog(
  BuildContext context,
  UpdateInfo update,
) {
  return showDialog<UpdateDialogAction>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(
        Icons.system_update_alt_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 32,
      ),
      title: Text('Доступна версия ${update.version}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 320),
        child: SingleChildScrollView(
          child: update.hasNotes
              ? Text(update.notes)
              : const Text('В этом релизе нет описания изменений.'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(UpdateDialogAction.skip),
          child: const Text('Пропустить'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(UpdateDialogAction.later),
          child: const Text('Позже'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(UpdateDialogAction.update),
          icon: const Icon(Icons.download_rounded, size: 20),
          label: const Text('Обновить'),
        ),
      ],
    ),
  );
}