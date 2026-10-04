import 'package:intl/intl.dart';

class DateFormatter {
  static final _ruFormat = DateFormat('dd MMMM yyyy', 'ru_RU');
  static final _enFormat = DateFormat('MMMM dd, yyyy', 'en_US');
  static final _shortRuFormat = DateFormat('dd.MM.yyyy', 'ru_RU');
  static final _shortEnFormat = DateFormat('MM/dd/yyyy', 'en_US');

  static String format(String? dateString, {bool short = false, String locale = 'ru'}) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      if (locale == 'ru') {
        return short ? _shortRuFormat.format(date) : _ruFormat.format(date);
      } else {
        return short ? _shortEnFormat.format(date) : _enFormat.format(date);
      }
    } catch (_) {
      return dateString;
    }
  }

  static String formatRelative(String? dateString, {String locale = 'ru'}) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date).inDays;

      if (locale == 'ru') {
        if (diff == 0) return 'Сегодня';
        if (diff == 1) return 'Вчера';
        if (diff < 7) return '$diff дн. назад';
        if (diff < 30) return '${(diff / 7).floor()} нед. назад';
        if (diff < 365) return '${(diff / 30).floor()} мес. назад';
        return '${(diff / 365).floor()} г. назад';
      } else {
        if (diff == 0) return 'Today';
        if (diff == 1) return 'Yesterday';
        if (diff < 7) return '$diff days ago';
        if (diff < 30) return '${(diff / 7).floor()} weeks ago';
        if (diff < 365) return '${(diff / 30).floor()} months ago';
        return '${(diff / 365).floor()} years ago';
      }
    } catch (_) {
      return dateString;
    }
  }
}