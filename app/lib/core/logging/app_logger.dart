import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  Logger? _logger;
  File? _logFile;
  Directory? _logDir;
  int _currentLogFileSize = 0;
  static const int _maxLogFileSize = 5 * 1024 * 1024;
  static const int _maxLogFiles = 3;

  Future<void> initialize() async {
    if (_logger != null) return;

    final primary = await _getLogDirectory();
    _logDir = primary;
    try {
      await _logDir!.create(recursive: true);
    } catch (_) {
      // Sandbox dir resolution/creation failed — fall back to a non-sandboxed
      // location so logging never goes silent.
      final home = Platform.environment['HOME'] ?? '.';
      _logDir = Directory(p.join(
          home, 'Library/Application Support/Moonlight Study/logs'));
      await _logDir!.create(recursive: true);
    }

    _logFile = File(p.join(_logDir!.path, 'moonlight_study.log'));
    if (await _logFile!.exists()) {
      _currentLogFileSize = await _logFile!.length();
    }

    _logger = Logger(
      filter: _AppLogFilter(),
      printer: _AppLogPrinter(),
      output: _FileOutput(_logFile!, this),
    );

    // Synchronous, guaranteed-on-disk proof that the app booted this far,
    // written before any drift/model work happens. Mirrored to stderr so a
    // terminal launch shows it even if file I/O fails.
    _writeBanner();
  }

  Future<Directory> _getLogDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Logging not supported on web');
    }
    final appDir = await getApplicationSupportDirectory();
    return Directory(p.join(appDir.path, 'logs'));
  }

  Future<void> _rotateLogFile() async {
    if (_logFile == null) return;

    final logDir = _logFile!.parent;
    final baseName = p.basenameWithoutExtension(_logFile!.path);
    final ext = p.extension(_logFile!.path);

    for (int i = _maxLogFiles - 1; i > 0; i--) {
      final oldFile = File(p.join(logDir.path, '$baseName.$i$ext'));
      final newFile = File(p.join(logDir.path, '$baseName.${i + 1}$ext'));
      if (await oldFile.exists()) {
        if (i == _maxLogFiles - 1) {
          await oldFile.delete();
        } else {
          await oldFile.rename(newFile.path);
        }
      }
    }

    if (await _logFile!.exists()) {
      await _logFile!.rename(p.join(logDir.path, '$baseName.1$ext'));
    }

    _logFile = File(p.join(logDir.path, '$baseName$ext'));
    _currentLogFileSize = 0;
  }

  void _writeBanner() {
    final line =
        '[${DateTime.now().toIso8601String()}] INFO: Moonlight Study starting';
    if (_logFile != null) {
      try {
        _logFile!.writeAsStringSync('$line\n',
            mode: FileMode.append, flush: true);
      } catch (e) {
        stderr.writeln('Failed to write startup banner: $e');
      }
    }
    stderr.writeln(line);
  }

  void _checkRotation() {
    if (_currentLogFileSize > _maxLogFileSize) {
      _rotateLogFile();
    }
  }

  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _logger?.d(message, error: error, stackTrace: stackTrace);
  }

  void info(String message, {Object? error, StackTrace? stackTrace}) {
    _logger?.i(message, error: error, stackTrace: stackTrace);
  }

  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _logger?.w(message, error: error, stackTrace: stackTrace);
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger?.e(message, error: error, stackTrace: stackTrace);
  }

  Future<List<String>> getRecentLogs({int maxLines = 500}) async {
    final logDir = _logDir ?? await _getLogDirectory();
    final logs = <String>[];

    for (int i = _maxLogFiles; i >= 0; i--) {
      final fileName = i == 0
          ? 'moonlight_study.log'
          : 'moonlight_study.$i.log';
      final file = File(p.join(logDir.path, fileName));

      if (await file.exists()) {
        final lines = await file.readAsLines();
        logs.addAll(lines);
        if (logs.length >= maxLines) {
          return logs.take(maxLines).toList();
        }
      }
    }

    return logs;
  }

  Future<void> clearLogs() async {
    final logDir = await _getLogDirectory();
    if (await logDir.exists()) {
      await for (final file in logDir.list()) {
        if (file is File && file.path.endsWith('.log')) {
          await file.delete();
        }
      }
    }
    _currentLogFileSize = 0;
  }

  Future<String> getLogFilePath() async {
    final logDir = _logDir ?? await _getLogDirectory();
    return p.join(logDir.path, 'moonlight_study.log');
  }
}

class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return kDebugMode || event.level.index >= Level.info.index;
  }
}

class _AppLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final time = DateTime.now().toIso8601String();
    final level = event.level.name.toUpperCase();
    final message = event.message;

    final buffer = StringBuffer();
    buffer.write('[$time] $level: $message');

    if (event.error != null) {
      buffer.write('\n  Error: ${event.error}');
    }

    if (event.stackTrace != null) {
      final stackLines = event.stackTrace.toString().split('\n');
      final relevantLines = stackLines.take(5).join('\n  ');
      buffer.write('\n  Stack trace:\n  $relevantLines');
    }

    return [buffer.toString()];
  }
}

class _FileOutput extends LogOutput {
  final File file;
  final AppLogger logger;

  _FileOutput(this.file, this.logger);

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      if (kDebugMode) {
        debugPrint(line);
      }
      _writeToFile(line);
    }
  }

  void _writeToFile(String line) {
    try {
      file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      logger._currentLogFileSize += line.length + 1;
      logger._checkRotation();
    } catch (e) {
      // Never swallow write failures silently — mirror to stderr so the
      // failure itself is observable.
      stderr.writeln('Failed to write to log file: $e\n$line');
    }
  }
}

final logger = AppLogger();
