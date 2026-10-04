class PushConstants {
  /// Общий топик, в который workflow шлёт сообщения о новых релизах.
  /// Должен совпадать с топиком в `.github/workflows/release.yml`.
  static const String topic = 'updates';

  /// Включил ли пользователь уведомления в настройках.
  static const String enabledKey = 'push_updates_enabled';
}