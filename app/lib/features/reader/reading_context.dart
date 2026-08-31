import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The PDF currently open in the reader. Shared with the Study Chat so it can
/// ground answers on the document the user is actually reading.
class ReadingContext {
  const ReadingContext({required this.documentId, required this.documentName});

  final int documentId;
  final String documentName;
}

/// Tracks the document the user is currently reading (set by the reader
/// screen on open, restore and PDF switch; cleared when the reader closes).
final readingContextProvider =
    NotifierProvider<ReadingContextNotifier, ReadingContext?>(ReadingContextNotifier.new);

class ReadingContextNotifier extends Notifier<ReadingContext?> {
  @override
  ReadingContext? build() => null;

  void open(int documentId, String documentName) {
    state = ReadingContext(documentId: documentId, documentName: documentName);
  }

  void clear() => state = null;
}
