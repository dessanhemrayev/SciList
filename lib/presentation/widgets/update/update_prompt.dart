import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/push_provider.dart';
import '../../providers/update_provider.dart';
import '../../routes/app_router.dart';
import 'update_dialog.dart';

/// Показывает диалог об обновлении, когда пришло push-сообщение.
///
/// Стоит внутри `MaterialApp.builder`, то есть выше Navigator, поэтому диалог
/// показывается через [rootNavigatorKey]. Провайдеры при этом доступны: они
/// созданы выше `MaterialApp`.
class UpdatePrompt extends StatefulWidget {
  const UpdatePrompt({super.key, required this.child});

  final Widget child;

  @override
  State<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends State<UpdatePrompt> {
  PushProvider? _push;
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _push = context.read<PushProvider>()..addListener(_onPushChanged);
    // Сообщение, по которому открыли приложение, попадает в очередь при
    // инициализации FCM — она успевает позже первого кадра.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPushChanged());
  }

  @override
  void dispose() {
    _push?.removeListener(_onPushChanged);
    super.dispose();
  }

  void _onPushChanged() {
    if (_isShowing || !mounted || _push?.hasMessages != true) return;
    unawaited(_showNext());
  }

  Future<void> _showNext() async {
    final message = _push?.takeMessage();
    if (message == null) return;
    await _checkAndPrompt();
  }

  /// Одна проверка с диалогом. Сообщение из очереди уже забрано и обратно не
  /// возвращается: повтор при сбое сети запускает только пользователь кнопкой
  /// «Повторить», иначе недоступная сеть привела бы к бесконечному циклу.
  Future<void> _checkAndPrompt() async {
    _isShowing = true;

    try {
      // Данным из push не доверяем: версию, заметки и ссылку на APK берём из
      // GitHub API, как при обычной проверке. «Пропустить версию» работает
      // так же, то есть пропущенный релиз повторно не предлагается.
      final updates = context.read<UpdateProvider>();
      final navigatorContext = rootNavigatorKey.currentContext;
      final (:result, :update) = await updates.checkFromPushDetailed();

      if (navigatorContext != null && navigatorContext.mounted) {
        if (update != null) {
          await presentUpdateDialog(navigatorContext, update);
        } else if (result == UpdateCheckResult.failed) {
          _showRetry(navigatorContext);
        }
      }
    } finally {
      _isShowing = false;
    }

    // Пока был открыт диалог, могли прийти ещё сообщения
    if (mounted) _onPushChanged();
  }

  void _showRetry(BuildContext navigatorContext) {
    ScaffoldMessenger.maybeOf(navigatorContext)?.showSnackBar(
      SnackBar(
        content: const Text('Не удалось проверить обновления'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Повторить',
          onPressed: () {
            if (_isShowing || !mounted) return;
            unawaited(_checkAndPrompt());
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}