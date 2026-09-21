import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../core/logging/app_logger.dart';

/// A document imported into a notebook, with extracted text.
class ImportedDocument {
  const ImportedDocument({
    required this.name,
    required this.kind,
    required this.filePath,
    this.pageCount = 0,
    this.text = '',
  });

  final String name;
  final String kind; // 'pdf' | 'image'
  final String filePath;
  final int pageCount;
  final String text;
}

/// High-level document library: import, extract, chunk.
class DocumentService {
  DocumentService();

  /// Recursively lists PDF file paths inside [folderPath].
  Future<List<String>> scanFolderForPdfs(String folderPath) async {
    final root = Directory(folderPath);
    if (!await root.exists()) return const [];
    final pdfs = <String>[];
    final stack = <Directory>[root];
    while (stack.isNotEmpty) {
      final dir = stack.removeLast();
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is Directory) {
            stack.add(entity);
          } else if (entity is File &&
              p.extension(entity.path).toLowerCase() == '.pdf') {
            pdfs.add(entity.path);
          }
        }
      } on FileSystemException catch (e) {
        logger.warning('Skipping unreadable subfolder: ${dir.path}', error: e);
      }
    }
    pdfs.sort();
    return pdfs;
  }

  /// Opens the platform file picker and imports PDFs/images/text into the
  /// library (stored in a notebook-bound folder inside the app documents).
  Future<ImportedDocument?> importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'txt', 'md'],
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final sourcePath = picked.path;
    if (sourcePath == null) return null;

    final name = picked.name;
    final ext = p.extension(name).toLowerCase();
    final kind = ext == '.pdf' ? 'pdf' : (ext == '.txt' || ext == '.md') ? 'text' : 'image';

    final docDir = await _docsDir();
    final dest = p.join(docDir.path, '${DateTime.now().millisecondsSinceEpoch}_$name');
    await File(sourcePath).copy(dest);

    return ImportedDocument(
      name: name,
      kind: kind,
      filePath: dest,
    );
  }

  /// Imports a file at [sourcePath] (already chosen by the caller) into the
  /// app documents directory, returning its [ImportedDocument].
  Future<ImportedDocument?> importDocumentAt(String sourcePath) async {
    final name = p.basename(sourcePath);
    final ext = p.extension(name).toLowerCase();
    final kind = ext == '.pdf'
        ? 'pdf'
        : (ext == '.txt' || ext == '.md')
            ? 'text'
            : 'image';

    final docDir = await _docsDir();
    final dest = p.join(docDir.path, '${DateTime.now().millisecondsSinceEpoch}_$name');
    await File(sourcePath).copy(dest);

    return ImportedDocument(
      name: name,
      kind: kind,
      filePath: dest,
    );
  }

  /// Reads raw text from a PDF (or returns '' for images, which go through
  /// the vision model instead).
  Future<String> extractText(ImportedDocument doc) async {
    if (doc.kind == 'image' || doc.kind == 'text' && doc.text.isNotEmpty) {
      if (doc.kind == 'text') {
        return File(doc.filePath).readAsString();
      }
      return '';
    }
    if (doc.kind == 'pdf') {
      return _extractPdfText(doc);
    }
    return '';
  }

  Future<String> _extractPdfText(ImportedDocument doc) async {
    try {
      final document = await pdfrx.PdfDocument.openFile(doc.filePath);
      final buffer = StringBuffer();
      for (var i = 0; i < document.pages.length; i++) {
        final page = document.pages[i];
        final text = await page.loadText();
        if (text != null && text.fullText.isNotEmpty) {
          buffer.writeln(text.fullText);
        }
      }
      await document.dispose();
      return buffer.toString();
    } catch (e, stackTrace) {
      logger.warning('Failed to extract text from ${doc.filePath}', error: e, stackTrace: stackTrace);
      return '';
    }
  }

  /// Splits extracted text into overlapping chunks for retrieval.
  List<String> chunkText(String text, {int size = 700, int overlap = 100}) {
    if (text.trim().isEmpty) return const [];
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= size) return [cleaned];

    final chunks = <String>[];
    var start = 0;
    while (start < cleaned.length) {
      var end = start + size;
      if (end < cleaned.length) {
        // Break at the last sentence boundary within the window.
        final window = cleaned.substring(start, end);
        final lastDot = window.lastIndexOf('. ');
        if (lastDot > size * 0.5) {
          end = start + lastDot + 1;
        }
      }
      chunks.add(cleaned.substring(start, end > cleaned.length ? cleaned.length : end));
      if (end >= cleaned.length) break;
      start = end - overlap;
    }
    return chunks;
  }

  /// Root folder for imported documents.
  Future<Directory> _docsDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'documents'));
    await dir.create(recursive: true);
    return dir;
  }
}

final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService();
});