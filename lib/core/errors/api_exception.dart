import 'package:dio/dio.dart';

abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

class NetworkException extends ApiException {
  const NetworkException({String message = 'Нет подключения к интернету', int? statusCode})
      : super(message, statusCode: statusCode);
}

class NotFoundException extends ApiException {
  const NotFoundException({String message = 'Журнал с указанным ISSN не найден', int? statusCode = 404})
      : super(message, statusCode: statusCode);
}

class ServerException extends ApiException {
  const ServerException({String message = 'Ошибка сервера. Попробуйте позже', int? statusCode = 500})
      : super(message, statusCode: statusCode);
}

class ValidationException extends ApiException {
  const ValidationException({required String message, int? statusCode = 400})
      : super(message, statusCode: statusCode);
}

class UnknownException extends ApiException {
  const UnknownException({String message = 'Неизвестная ошибка', int? statusCode})
      : super(message, statusCode: statusCode);
}

ApiException handleDioError(dynamic error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(message: 'Превышено время ожидания');
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        switch (statusCode) {
          case 400:
            return const ValidationException(message: 'Неверный формат ISSN');
          case 404:
            return const NotFoundException();
          case 500:
          case 502:
          case 503:
            return const ServerException();
          default:
            return UnknownException(
              message: 'Ошибка сервера: ${statusCode ?? 'неизвестно'}',
              statusCode: statusCode,
            );
        }
      case DioExceptionType.cancel:
        return const UnknownException(message: 'Запрос отменён');
      case DioExceptionType.unknown:
        if (error.message?.contains('SocketException') ?? false) {
          return const NetworkException();
        }
        return UnknownException(message: error.message ?? 'Неизвестная ошибка');
      default:
        return const UnknownException();
    }
  }
  return const UnknownException();
}