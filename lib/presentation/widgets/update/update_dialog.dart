import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/update_info.dart';
import '../../../data/services/update_service.dart';
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
      if (provider.isAndroid) {
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _UpdateDownloadDialog(
            provider: provider,
            update: update,
          ),
        );
      } else {
        final opened = await provider.openDownload(update);
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть ссылку на загрузку')),
          );
        }
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

class _UpdateDownloadDialog extends StatefulWidget {
  const _UpdateDownloadDialog({required this.provider, required this.update});

  final UpdateProvider provider;
  final UpdateInfo update;

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  bool _downloadComplete = false;
  bool _downloadFailed = false;
  bool _installFailed = false;
  bool _installPermissionRequired = false;
  bool _isInstalling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  Future<void> _download() async {
    setState(() {
      _downloadFailed = false;
      _installFailed = false;
      _installPermissionRequired = false;
    });
    final success = await widget.provider.downloadUpdate(widget.update);
    if (!mounted) return;
    setState(() {
      _downloadComplete = success;
      _downloadFailed = !success;
    });
  }

  Future<void> _install() async {
    setState(() => _isInstalling = true);
    final result = await widget.provider.installDownloadedUpdate();
    if (!mounted) return;
    switch (result) {
      case InstallApkResult.opened:
        Navigator.of(context).pop(true);
      case InstallApkResult.permissionRequired:
        setState(() {
          _isInstalling = false;
          _installPermissionRequired = true;
          _installFailed = false;
        });
      case InstallApkResult.failed:
        setState(() {
          _isInstalling = false;
          _installFailed = true;
        });
    }
  }

  Future<void> _openInstallSettings() async {
    final opened = await widget.provider.openInstallSettings();
    if (!mounted || opened) return;
    setState(() => _installFailed = true);
  }

  Future<void> _cancelDownload() async {
    await widget.provider.cancelDownload();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.provider,
      builder: (context, _) {
        final progress = widget.provider.downloadProgress;
        return PopScope(
          canPop: !widget.provider.isDownloading,
          child: AlertDialog(
            title: Text(
              _downloadComplete ? 'Обновление скачано' : 'Загрузка версии ${widget.update.version}',
            ),
            content: SizedBox(
              width: 320,
              child: _downloadFailed
                  ? const Text('Не удалось скачать обновление. Проверьте подключение и попробуйте ещё раз.')
                  : _downloadComplete
                      ? Text(
                          _installPermissionRequired
                            ? 'Разрешите установку приложений из этого источника в настройках Android, затем вернитесь и нажмите «Установить».'
                            : _installFailed
                              ? 'Не удалось открыть установщик. Попробуйте установить файл ещё раз.'
                              : 'Версия ${widget.update.version} готова к установке.',
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 12),
                            Text(
                              progress == null
                                  ? 'Загрузка...'
                                  : 'Загрузка... ${(progress * 100).round()}%',
                            ),
                          ],
                        ),
            ),
            actions: [
              if (widget.provider.isDownloading)
                TextButton(
                  onPressed: _cancelDownload,
                  child: const Text('Отмена'),
                ),
              if (_downloadFailed)
                TextButton(onPressed: _download, child: const Text('Повторить')),
              if (_downloadComplete) ...[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Позже'),
                ),
                if (_installPermissionRequired)
                  TextButton.icon(
                    onPressed: _openInstallSettings,
                    icon: const Icon(Icons.settings_rounded, size: 20),
                    label: const Text('Настройки'),
                  ),
                FilledButton.icon(
                  onPressed: _isInstalling ? null : _install,
                  icon: const Icon(Icons.install_mobile_rounded, size: 20),
                  label: Text(_isInstalling ? 'Открываем...' : 'Установить'),
                ),
              ],
              if (_downloadFailed)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Закрыть'),
                ),
            ],
          ),
        );
      },
    );
  }
}