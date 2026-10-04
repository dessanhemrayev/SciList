import 'package:flutter/foundation.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/models/journal.dart';

class JournalProvider extends ChangeNotifier {
  final JournalRepository _repository;

  Journal? _journal;
  bool _isLoading = false;
  String? _error;
  String? _lastQueriedIssn;

  JournalProvider({JournalRepository? repository})
      : _repository = repository ?? JournalRepository();

  Journal? get journal => _journal;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get lastQueriedIssn => _lastQueriedIssn;
  bool get hasJournal => _journal != null;

  Future<void> fetchJournal(String issn) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _lastQueriedIssn = issn;
    notifyListeners();

    try {
      final response = await _repository.getJournalByIssn(issn);
      if (response.isSuccess) {
        _journal = response.data;
        _error = null;
      } else {
        _journal = null;
        _error = response.error;
      }
    } catch (e) {
      _journal = null;
      _error = 'Ошибка: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _journal = null;
    _error = null;
    _lastQueriedIssn = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}