class ApiConstants {
  static const String baseUrl = 'https://journalrank.rcsi.science/api';
  static const String recordSourcesEndpoint = '/record-sources';
  static const String levelEndpoint = '/level';

  static const int connectTimeoutMs = 10000;
  static const int receiveTimeoutMs = 30000;

  static String getJournalLevelUrl(String issn) {
    return '$baseUrl$recordSourcesEndpoint/$issn$levelEndpoint';
  }
}