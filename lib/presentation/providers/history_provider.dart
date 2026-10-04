import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/journal.dart';

class HistoryProvider extends ChangeNotifier {
  static const _historyKey = 'search_history';
  static const _maxHistoryItems = 50;

  final SharedPreferences _prefs;
  List<Journal> _history = [];

  HistoryProvider(this._prefs) {
    _loadHistory();
  }

  List<Journal> get history => List.unmodifiable(_history);
  bool get isEmpty => _history.isEmpty;
  int get length => _history.length;

  Future<void> _loadHistory() async {
    final jsonString = _prefs.getString(_historyKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _history = decoded
            .map((e) => Journal.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } catch (_) {
        _history = [];
      }
    }
  }

  Future<void> addToHistory(Journal journal) async {
    _history.removeWhere((j) => j.primaryIssn == journal.primaryIssn);
    _history.insert(0, journal);
    if (_history.length > _maxHistoryItems) {
      _history = _history.sublist(0, _maxHistoryItems);
    }
    await _saveHistory();
    notifyListeners();
  }

  Future<void> removeFromHistory(String issn) async {
    _history.removeWhere((j) => j.primaryIssn == issn);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final jsonString = jsonEncode(_history.map((j) => j.toJson()).toList());
    await _prefs.setString(_historyKey, jsonString);
  }
}