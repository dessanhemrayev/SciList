class UpdateConstants {
  static const String githubOwner = 'dessanhemrayev';
  static const String githubRepo = 'SciList';

  /// Лимит GitHub без токена — 60 запросов в час на IP, поэтому проверка
  /// не чаще одного раза в [checkIntervalHours].
  static const int checkIntervalHours = 6;

  static String get latestReleaseUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  static String get releasesPageUrl =>
      'https://github.com/$githubOwner/$githubRepo/releases';

  static const int connectTimeoutMs = 10000;
  static const int receiveTimeoutMs = 15000;

  static const String lastCheckKey = 'update_last_check_at';
  static const String skippedVersionKey = 'update_skipped_version';
}