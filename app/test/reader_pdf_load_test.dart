import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

/// Regression test for the reader's "first PDF doesn't load" bug.
///
/// ReaderScreen keys the pdfrx viewer by `(generation, documentId)` and
/// remounts it (fresh load) whenever the displayed document changes or a
/// stalled cold-start load is retried. This test pins the load machinery to
/// that contract:
///   1. A fresh `PdfViewer.file` mount with a shared controller reaches
///      `isReady` (cold-start loads must not stay blank forever).
///   2. Re-keying the viewer (our remount/retry mechanism) against the same
///      path and same controller re-opens the document and reaches ready.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late File file;
  late pdfrx.PdfViewerController controller;

  setUpAll(() async {
    pdfrx.pdfrxInitialize();
    final dir = await Directory.systemTemp.createTemp('pdfrx-load-test');
    file = File('${dir.path}/tiny.pdf');
    await file.writeAsBytes(_buildOnePagePdf());
    addTearDown(() => dir.delete(recursive: true));
  });

  setUp(() {
    controller = pdfrx.PdfViewerController();
  });

  Widget viewer(double width, double height, Key key) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: KeyedSubtree(
              key: key,
              child: pdfrx.PdfViewer.file(
                file.path,
                controller: controller,
                params: const pdfrx.PdfViewerParams(
                  behaviorControlParams: pdfrx.PdfViewerBehaviorControlParams(
                    trailingPageLoadingDelay: Duration.zero,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpUntilReady(
    WidgetTester tester, {
    required Key key,
    int maxPumps = 60,
  }) async {
    await tester.pumpWidget(viewer(600, 800, key));
    for (var i = 0; i < maxPumps && !controller.isReady; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }

  testWidgets('fresh PdfViewer.file mount with a controller reaches ready',
      (tester) async {
    await binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => binding.setSurfaceSize(null));

    await pumpUntilReady(tester, key: const ValueKey('gen0'));

    expect(tester.takeException(), isNull);
    expect(controller.isReady, isTrue,
        reason: 'a mounted PdfViewer.file should open its document');
    expect(controller.pageCount, greaterThanOrEqualTo(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('re-keying the viewer (reader retry) reloads via the controller',
      (tester) async {
    await binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => binding.setSurfaceSize(null));

    // Simulate the reader's generation-key remount: same file path, same
    // controller, different widget key. This is exactly what _armStuckLoadWatch
    // / the settle logic does, and it must end up ready.
    await pumpUntilReady(tester, key: const ValueKey('gen1'));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(viewer(600, 800, const ValueKey('gen2')));
    for (var i = 0; i < 60 && !controller.isReady; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }

    expect(tester.takeException(), isNull);
    expect(controller.isReady, isTrue,
        reason: 'a re-keyed remount must reload the document to ready');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}

/// Builds a minimal one-page, blank A4 PDF with correct xref offsets.
List<int> _buildOnePagePdf() {
  final objects = <String>[
    '<</Type/Catalog/Pages 2 0 R>>',
    '<</Type/Pages/Kids[3 0 R]/Count 1>>',
    '<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842>>',
  ];

  final body = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(body.length);
    body.writeln('${i + 1} 0 obj');
    body.writeln(objects[i]);
    body.writeln('endobj');
  }

  final xrefStart = body.length;
  body.writeln('xref');
  body.writeln('0 ${objects.length + 1}');
  body.writeln('0000000000 65535 f ');
  for (final offset in offsets) {
    body.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
  }
  body.writeln('trailer');
  body.writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>');
  body.writeln('startxref');
  body.writeln('$xrefStart');
  body.writeln('%%EOF');

  return body.toString().codeUnits;
}