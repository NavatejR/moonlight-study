import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:llamadart/llamadart.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../core/ai/ai_engine.dart';
import '../core/logging/app_logger.dart';

/// OCR by asking the on-device vision model to transcribe rendered PDF pages.
///
/// This is the cross-platform fallback that needs no extra native dependencies:
/// pages are rasterized with pdfrx, encoded as PNG and fed to the active
/// vision-capable model (e.g. qwen2.5-vl-3b). It only runs when such a model
/// is actually loaded and ready; otherwise it returns empty text.
class OcrService {
  OcrService(this._ref);

  final Ref _ref;

  bool get _visionReady {
    if (!_ref.read(aiEnabledProvider)) return false;
    final active = _ref.read(activeModelProvider);
    if (!active.isVision) return false;
    return _ref.read(aiEngineProvider).status == AiStatus.ready;
  }

  /// Transcribes every page of the PDF at [path], reporting progress as
  /// `(pageCurrent, pageTotal)`. Returns concatenated text, or '' when the
  /// vision model isn't available or the document can't be opened.
  Future<String> recognizeFile(
    String path, {
    void Function(int page, int total)? onProgress,
  }) async {
    if (!_ref.read(aiEnabledProvider)) return '';
    final active = _ref.read(activeModelProvider);
    if (!active.isVision) return '';
    // Load the vision model on demand (single-flight shares the startup/chat
    // load task). If it still isn't ready, skip OCR gracefully for this run.
    if (_ref.read(aiEngineProvider).status != AiStatus.ready) {
      await _ref.read(aiEngineProvider.notifier).ensureModelLoaded();
    }
    if (!_visionReady) return '';
    pdfrx.PdfDocument? document;
    try {
      document = await pdfrx.PdfDocument.openFile(path);
      final pages = document.pages;
      final buffer = StringBuffer();
      for (var i = 0; i < pages.length; i++) {
        onProgress?.call(i + 1, pages.length);
        final pageText = await _recognizePage(pages[i]);
        if (pageText.trim().isNotEmpty) {
          buffer.write(pageText.trim());
          buffer.write('\n\n');
        }
      }
      return buffer.toString();
    } catch (e, stackTrace) {
      logger.warning('OCR failed for $path', error: e, stackTrace: stackTrace);
      return '';
    } finally {
      await document?.dispose();
    }
  }

  Future<String> _recognizePage(pdfrx.PdfPage page) async {
    const targetWidth = 1800;
    final pageHeight = page.height / (page.width == 0 ? 1 : page.width);
    final image = await page.render(
      fullWidth: targetWidth.toDouble(),
      fullHeight: targetWidth * pageHeight,
    );
    if (image == null) return '';
    try {
      final engine = _ref.read(aiEngineProvider.notifier);
      final bytes = _encodePng(image);
      final buffer = StringBuffer();
      await for (final delta in engine.transcribe([
        LlamaImageContent(
          bytes: bytes,
          width: image.width,
          height: image.height,
        ),
        LlamaTextContent(
          'Transcribe all the text on this page verbatim. Preserve '
          'mathematical notation exactly: write exponents with "^" (e.g. '
          '10^9, never 109), subscripts with "_" (e.g. x_1), fractions as '
          '"a/b", and keep symbols such as x, /, =, so, pi, sum, infinity. '
          'Never merge or drop a superscript, subscript or symbol. Output '
          'only the text exactly as written, with no commentary.',
        ),
      ])) {
        buffer.write(delta);
      }
      return buffer.toString();
    } finally {
      image.dispose();
    }
  }

  Uint8List _encodePng(pdfrx.PdfImage image) {
    final decoded = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.pixels.buffer,
      order: img.ChannelOrder.bgra,
    );
    return Uint8List.fromList(img.encodePng(decoded));
  }
}

final ocrServiceProvider = Provider<OcrService>((ref) => OcrService(ref));