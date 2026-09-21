import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../logging/app_logger.dart';

class ModelDownloadError implements Exception {
  final String message;
  final Object? cause;

  ModelDownloadError(this.message, [this.cause]);

  @override
  String toString() => 'ModelDownloadError: $message';
}

class PDFCorruptedError implements Exception {
  final String filePath;
  final Object? cause;

  PDFCorruptedError(this.filePath, [this.cause]);

  @override
  String toString() => 'PDFCorruptedError: $filePath';
}

class DiskSpaceError implements Exception {
  final int requiredBytes;
  final int availableBytes;

  DiskSpaceError(this.requiredBytes, this.availableBytes);

  @override
  String toString() =>
      'DiskSpaceError: Need ${_formatBytes(requiredBytes)}, '
      'only ${_formatBytes(availableBytes)} available';

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class NetworkError implements Exception {
  final String message;
  final Object? cause;

  NetworkError(this.message, [this.cause]);

  @override
  String toString() => 'NetworkError: $message';
}

class FilePermissionError implements Exception {
  final String filePath;
  final Object? cause;

  FilePermissionError(this.filePath, [this.cause]);

  @override
  String toString() => 'FilePermissionError: $filePath';
}

class ErrorHandler {
  static void handle(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    BuildContext? buildContext,
    bool showSnackBar = true,
  }) {
    final message = getUserMessage(error);
    final logMessage = context != null ? '$context: $message' : message;

    logger.error(logMessage, error: error, stackTrace: stackTrace);

    if (showSnackBar && buildContext != null && buildContext.mounted) {
      _showErrorSnackBar(buildContext, message);
    }
  }

  static String getUserMessage(Object error) {
    if (error is ModelDownloadError) {
      return 'Failed to download model: ${error.message}. '
          'Check your internet connection and try again.';
    }

    if (error is PDFCorruptedError) {
      return 'This PDF file appears to be corrupted or invalid. '
          'Please try a different file.';
    }

    if (error is DiskSpaceError) {
      return 'Not enough disk space. Need ${error._formatBytes(error.requiredBytes)}, '
          'but only ${error._formatBytes(error.availableBytes)} available. '
          'Free up some space and try again.';
    }

    if (error is NetworkError) {
      return 'Network error: ${error.message}. '
          'Check your internet connection and try again.';
    }

    if (error is FilePermissionError) {
      return 'Cannot access file. Please check file permissions.';
    }

    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return 'This model lives behind a gated repository. '
            'Add a Hugging Face read token in Settings → AI '
            'to download it.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Connection timed out. Check your internet and try again.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network and try again.';
      }
      if (status != null && status >= 500) {
        return 'The model server had a problem (HTTP $status). '
            'Try again in a moment.';
      }
      return 'Network error downloading file (HTTP ${status ?? 'unknown'}). '
          'Please try again.';
    }

    if (error is FileSystemException) {
      return 'File system error: ${error.message}. '
          'Please check file permissions and try again.';
    }

    if (error is FormatException) {
      return 'Invalid file format. Please check the file and try again.';
    }

    if (error is TimeoutException) {
      return 'Operation timed out. Please try again.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
