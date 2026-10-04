import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/api_exception.dart';
import '../models/journal.dart';
import '../models/api_response.dart';

class JournalApiClient {
  final Dio _dio;

  JournalApiClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: Duration(milliseconds: ApiConstants.connectTimeoutMs),
                receiveTimeout: Duration(milliseconds: ApiConstants.receiveTimeoutMs),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json; charset=utf-8',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  Future<ApiResponse<Journal>> getJournalByIssn(String issn) async {
    try {
      final cleanIssn = issn.replaceAll('-', '').toUpperCase();
      final response = await _dio.get(
        '${ApiConstants.recordSourcesEndpoint}/$cleanIssn${ApiConstants.levelEndpoint}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final journal = Journal.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse.success(journal);
      } else if (response.statusCode == 404) {
        return const ApiResponse.error('Журнал с указанным ISSN не найден', statusCode: 404);
      } else {
        return ApiResponse.error(
          'Ошибка сервера: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      final apiException = handleDioError(e);
      return ApiResponse.error(apiException.message, statusCode: apiException.statusCode);
    } catch (e) {
      return ApiResponse.error('Неизвестная ошибка: $e');
    }
  }

  void dispose() {
    _dio.close();
  }
}