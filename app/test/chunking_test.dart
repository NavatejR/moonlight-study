import 'package:study_companion/docs/document_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentService.chunkText', () {
    final service = DocumentService();

    test('handles empty and whitespace text', () {
      expect(service.chunkText(''), isEmpty);
      expect(service.chunkText('   \n  '), isEmpty);
    });

    test('short text becomes a single chunk', () {
      final chunks = service.chunkText('One paragraph.');
      expect(chunks, hasLength(1));
      expect(chunks.single, contains('One paragraph'));
    });

    test('text at/under window size is not split', () {
      final body = 'word ' * 130; // 649 chars, one paragraph, under size 700
      final chunks = service.chunkText(body);
      expect(chunks, hasLength(1));
      expect(chunks.single.length, body.trim().length);
    });

    test('long text splits into multiple sequential chunks', () {
      final body = 'word ' * 400; // ~2000 chars, one paragraph
      final chunks = service.chunkText(body);
      expect(chunks.length, greaterThan(1));
      final wordCount =
          chunks.fold<int>(0, (n, c) => n + 'word '.allMatches(c).length);
      expect(wordCount, greaterThanOrEqualTo(400),
          reason: 'no content should be dropped across chunks');
    });

    test('chunks respect the configured window size', () {
      final body = 'word ' * 500;
      final chunks = service.chunkText(body);
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(800),
            reason: 'chunk exceeds window (+overlap)');
      }
    });

    test('each boundary chunk carries a readable tail', () {
      final body = '${'alpha ' * 100}\n\n${'beta ' * 100}\n\n${'gamma ' * 100}';
      final chunks = service.chunkText(body, size: 300, overlap: 50);
      expect(chunks, isNotEmpty);
      for (final c in chunks) {
        expect(c.trim(), isNotEmpty);
      }
    });

    test('preserves paragraph boundaries when possible', () {
      final body = 'First paragraph.\n\nSecond paragraph.\n\n${'Third paragraph with lots of words. ' * 8}';
      final chunks = service.chunkText(body, size: 250, overlap: 0);
      // Should be split into separate chunks, one starting with "First"
      final firstStarts =
          chunks.where((c) => c.trimLeft().startsWith('First')).toList();
      expect(firstStarts, hasLength(1));
    });
  });
}