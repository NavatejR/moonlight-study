import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/app_logger.dart';
import '../../core/theme/colors.dart';

/// A debug viewer for the app's log files, reachable from Settings → Logs.
///
/// Lets a user (or someone helping them) inspect recent log entries, search
/// them, copy them to the clipboard, or export the raw log file. Helpful for
/// troubleshooting without requiring a terminal.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  List<String> _logs = const [];
  bool _loading = true;
  String _filter = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await logger.getRecentLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _copy() async {
    final text = _logs.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  Future<void> _export() async {
    try {
      final path = await logger.getLogFilePath();
      final file = File(path);
      if (!await file.exists()) {
        _showMessage('No log file exists yet.');
        return;
      }
      final bytes = await file.readAsBytes();
      final home = await getApplicationSupportDirectory();
      final exportPath = '${home.path}/moonlight_study_logs_${DateTime.now().millisecondsSinceEpoch}.txt';
      await File(exportPath).writeAsBytes(bytes);
      _showMessage('Logs exported to $exportPath');
    } catch (e) {
      _showMessage('Export failed: $e');
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all logs?'),
        content: const Text(
          'This removes every saved log entry. '
          'Doing this can make future troubleshooting harder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await logger.clearLogs();
    await _load();
    _showMessage('Logs cleared.');
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.isEmpty
        ? _logs
        : _logs.where((l) => l.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Copy to clipboard',
            icon: const Icon(Icons.copy),
            onPressed: _logs.isEmpty ? null : _copy,
          ),
          IconButton(
            tooltip: 'Export log file',
            icon: const Icon(Icons.ios_share),
            onPressed: _logs.isEmpty ? null : _export,
          ),
          IconButton(
            tooltip: 'Clear logs',
            icon: const Icon(Icons.delete_outline),
            onPressed: _logs.isEmpty ? null : _confirmClear,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _filter = v),
              decoration: InputDecoration(
                hintText: 'Search logs…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filter.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filter = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const _EmptyLogs()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final line = filtered[index];
                          final isError = line.contains('ERROR') || line.contains('WARN');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: SelectableText(
                              line,
                              style: TextStyle(
                                fontFamily: 'Menlo',
                                fontSize: 11,
                                color: isError
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLogs extends StatelessWidget {
  const _EmptyLogs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.article_outlined, size: 56, color: CoffeeColors.latte),
          const SizedBox(height: 12),
          Text(
            'No logs yet.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Logs will appear here as you use the app.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}