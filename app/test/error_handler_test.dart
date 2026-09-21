import 'dart:async';
import 'dart:io';

import 'package:study_companion/core/errors/error_handler.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorHandler.getUserMessage', () {
    test('ModelDownloadError includes cause', () {
      final msg = ErrorHandler.getUserMessage(
        ModelDownloadError('Disk full'),
      );
      expect(msg, contains('Failed to download model'));
      expect(msg, contains('Disk full'));
      expect(msg, contains('internet'));
    });

    test('PDFCorruptedError', () {
      final msg = ErrorHandler.getUserMessage(
        PDFCorruptedError('/tmp/bad.pdf'),
      );
      expect(msg, contains('corrupted'));
    });

    test('DiskSpaceError formats bytes', () {
      final msg = ErrorHandler.getUserMessage(
        DiskSpaceError(2 * 1024 * 1024 * 1024, 500 * 1024 * 1024),
      );
      expect(msg, contains('2.0 GB'));
      expect(msg, contains('500.0 MB'));
    });

    test('NetworkError', () {
      final msg = ErrorHandler.getUserMessage(
        NetworkError('Connection refused'),
      );
      expect(msg, contains('Network error'));
      expect(msg, contains('Connection refused'));
    });

    test('FilePermissionError', () {
      final msg = ErrorHandler.getUserMessage(
        FilePermissionError('/tmp/secret.txt'),
      );
      expect(msg, contains('permission'));
    });

    test('SocketException → no internet', () {
      final msg = ErrorHandler.getUserMessage(
        const SocketException('Connection reset'),
      );
      expect(msg, contains('No internet connection'));
    });

    test('DioException 401 → gated model guidance', () {
      final msg = ErrorHandler.getUserMessage(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 401,
          ),
        ),
      );
      expect(msg, contains('gated'));
      expect(msg, contains('Settings'));
      expect(msg, contains('token'));
    });

    test('DioException 503 → server error', () {
      final msg = ErrorHandler.getUserMessage(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 503,
          ),
        ),
      );
      expect(msg, contains('503'));
      expect(msg, contains('Try again'));
    });

    test('DioException connection error → no internet', () {
      final msg = ErrorHandler.getUserMessage(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(msg, contains('No internet'));
    });

    test('TimeoutException', () {
      final msg = ErrorHandler.getUserMessage(
        TimeoutException('timed out'),
      );
      expect(msg, contains('timed out'));
    });

    test('FormatException', () {
      final msg = ErrorHandler.getUserMessage(
        const FormatException('bad json'),
      );
      expect(msg, contains('Invalid file format'));
    });

    test('unknown error returns generic message', () {
      final msg = ErrorHandler.getUserMessage(Exception('??'));
      expect(msg, contains('unexpected error'));
    });
  });
}
