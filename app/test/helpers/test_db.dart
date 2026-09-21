import 'package:study_companion/core/db/app_database.dart';
import 'package:drift/native.dart';

/// Opens an in-memory [AppDatabase] with the schema created. Fast and
/// dependency-free — no path_provider, no native SQLite file.
Future<AppDatabase> openInMemoryDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.customStatement('PRAGMA foreign_keys = ON');
  return db;
}