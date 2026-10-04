import '../datasources/journal_api_client.dart';
import '../models/journal.dart';
import '../models/api_response.dart';

class JournalRepository {
  final JournalApiClient _apiClient;

  JournalRepository({JournalApiClient? apiClient})
      : _apiClient = apiClient ?? JournalApiClient();

  Future<ApiResponse<Journal>> getJournalByIssn(String issn) async {
    return await _apiClient.getJournalByIssn(issn);
  }

  void dispose() {
    _apiClient.dispose();
  }
}