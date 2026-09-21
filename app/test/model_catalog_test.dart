import 'package:study_companion/core/ai/model_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelCatalog', () {
    test('all models have unique ids', () {
      final ids = ModelCatalog.all.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate model ids');
    });

    test('all models have hunane-readable names and metrics', () {
      for (final e in ModelCatalog.all) {
        expect(e.name.trim(), isNotEmpty);
        expect(e.tagline.trim(), isNotEmpty);
        expect(e.sizeLabel.trim(), isNotEmpty);
        expect(e.ramLabel.trim(), isNotEmpty);
        expect(e.speedLabel.trim(), isNotEmpty);
        expect(e.capabilities, isNotEmpty);
      }
    });

    test('default model is the vision one', () {
      final defaults = ModelCatalog.all.where((e) => e.isDefault).toList();
      expect(defaults, hasLength(1));
      expect(defaults.single.capabilities, contains(AiCapability.vision));
    });

    test('vision model ships a projector source', () {
      final vision = ModelCatalog.all
          .where((e) => e.capabilities.contains(AiCapability.vision))
          .toList();
      for (final e in vision) {
        expect(e.projectorSource, isNotNull);
      }
    });

    test('embedding model is not a chat model', () {
      final emb = ModelCatalog.all
          .where((e) => e.capabilities.contains(AiCapability.embeddings))
          .toList();
      expect(emb, hasLength(1));
      expect(emb.single.capabilities, isNot(contains(AiCapability.chat)));
    });

    test('all sources are remote URLs', () {
      for (final e in ModelCatalog.all) {
        expect(e.source.isRemote, isTrue,
            reason: '${e.id} must be a remote source');
        final url = e.source.url.toString();
        expect(
          url.startsWith('hf://') ||
              (url.contains('huggingface.co') && url.startsWith('http')),
          isTrue,
          reason: '${e.id} source must be an hf:// or huggingface.co URL',
        );
        if (e.projectorSource != null) {
          expect(e.projectorSource!.isRemote, isTrue);
        }
      }
    });

    test('byId returns default for unknown id', () {
      expect(ModelCatalog.byId('nope'), ModelCatalog.qwenVl);
      expect(ModelCatalog.byId('qwen2.5-1.5b'), ModelCatalog.qwenText);
      expect(ModelCatalog.byId(null), ModelCatalog.qwenVl);
    });

    test('recommended model is the default', () {
      expect(
        ModelCatalog.recommendedForTypicalDevice,
        ModelCatalog.qwenVl,
      );
      expect(
        ModelCatalog.recommendedForTypicalDevice.isVision,
        isTrue,
      );
    });

    test('low-ram picks avoid the biggest model', () {
      final ids = ModelCatalog.recommendedForLowRam.map((e) => e.id).toSet();
      expect(ids, isNot(contains('qwen2.5-vl-3b')));
      expect(ModelCatalog.recommendedForLowRam, isNotEmpty);
    });
  });
}