import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/db/app_database.dart';
import '../../core/logging/app_logger.dart';
import '../../docs/document_service.dart';
import '../../docs/rag_service.dart';

/// Auto-imports the bundled "Getting Started" PDF during first-run onboarding.
///
/// Copies assets/docs/getting_started.pdf into the app's document folder,
/// creates a "Welcome" notebook, and indexes the document so it's immediately
/// queryable by the AI assistant.
Future<void> importSampleDocument(AppDatabase db, WidgetRef ref) async {
  final logger = AppLogger();
  
  try {
    logger.info('Importing sample Getting Started PDF for first run');

    final bytes = await rootBundle.load('assets/docs/getting_started.pdf');
    final tempDir = Directory.systemTemp.createTempSync('moonlight_onboarding');
    final tempFile = File(p.join(tempDir.path, 'getting_started.pdf'));
    await tempFile.writeAsBytes(bytes.buffer.asUint8List());

    final docService = DocumentService();
    final ragService = ref.read(ragServiceProvider);

    var welcomeNotebook = await (db.select(db.notebooks)
          ..where((n) => n.title.equals('Welcome')))
        .getSingleOrNull();

    if (welcomeNotebook == null) {
      final id = await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(title: 'Welcome'),
          );
      welcomeNotebook = await (db.select(db.notebooks)
            ..where((n) => n.id.equals(id)))
          .getSingle();
      logger.info('Created Welcome notebook (id=$id)');
    }

    final imported = await docService.importDocumentAt(tempFile.path);
    if (imported == null) {
      logger.warning('importDocumentAt returned null for sample PDF');
      return;
    }

    final docId = await ragService.indexDocument(imported);

    await db.into(db.notebookDocuments).insert(
      NotebookDocumentsCompanion.insert(
        notebookId: welcomeNotebook.id,
        documentId: docId,
      ),
    );

    await tempFile.delete();
    await tempDir.delete();

    logger.info('Sample document imported successfully (docId=$docId)');
  } catch (e, st) {
    logger.error('Failed to import sample document', error: e, stackTrace: st);
  }
}
