import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/journal.dart';

class FavoritesProvider extends ChangeNotifier {
  static const _favoritesKey = 'favorites';

  final SharedPreferences _prefs;
  List<Journal> _favorites = [];

  FavoritesProvider(this._prefs) {
    _loadFavorites();
  }

  List<Journal> get favorites => List.unmodifiable(_favorites);
  bool get isEmpty => _favorites.isEmpty;
  int get length => _favorites.length;

  bool isFavorite(String issn) {
    return _favorites.any((j) => j.primaryIssn == issn);
  }

  Future<void> _loadFavorites() async {
    final jsonString = _prefs.getString(_favoritesKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _favorites = decoded
            .map((e) => Journal.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } catch (_) {
        _favorites = [];
      }
    }
  }

  Future<void> toggleFavorite(Journal journal) async {
    final issn = journal.primaryIssn;
    final index = _favorites.indexWhere((j) => j.primaryIssn == issn);
    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      _favorites.insert(0, journal);
    }
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> removeFavorite(String issn) async {
    _favorites.removeWhere((j) => j.primaryIssn == issn);
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> clearFavorites() async {
    _favorites.clear();
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final jsonString = jsonEncode(_favorites.map((j) => j.toJson()).toList());
    await _prefs.setString(_favoritesKey, jsonString);
  }
}