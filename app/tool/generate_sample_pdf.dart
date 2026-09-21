// Generates the bundled "Getting Started with Moonlight Study" sample PDF
// (assets/docs/getting_started.pdf) that's auto-imported during onboarding.
//
//   dart run tool/generate_sample_pdf.dart
//
// The output is committed so users get a polished first-run experience even
// when fully offline.
//
// Uses the `pdf` package (already a runtime dependency for export features).
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _caramel = PdfColor.fromInt(0xFFC08A55);
const _espresso = PdfColor.fromInt(0xFF2E2014);
const _cacao = PdfColor.fromInt(0xFF6F5A44);
const _crema = PdfColor.fromInt(0xFFF7F0E6);

Future<void> main() async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 52, vertical: 48),
        buildBackground: (context) =>
            pw.Container(color: _crema),
      ),
      header: (context) => pw.Container(
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: _caramel, width: 1.5),
          ),
        ),
        child: pw.Row(
          children: [
            pw.Text(
              '☕',
              style: pw.TextStyle(fontSize: 18),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Moonlight Study',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: _espresso,
              ),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          'Moonlight Study — your local study companion',
          style: pw.TextStyle(color: _cacao, fontSize: 9),
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 24),
        pw.Text(
          'Getting Started with Moonlight Study',
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            color: _espresso,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'A gentle tour of your new local-first AI study companion',
          style: pw.TextStyle(color: _cacao, fontSize: 13),
        ),
        pw.SizedBox(height: 28),

        _section('What is Moonlight Study?'),
        pw.Paragraph(
          text:
              'Moonlight Study turns the documents you already own into a '
              'private, on-device study companion. Everything — reading, '
              'highlighting, note-taking, flashcard generation, and AI answers '
              'grounded in your material — runs locally on your machine. '
              'Nothing is uploaded, no account is required, and once your '
              'model is downloaded the app works completely offline.',
        ),
        pw.SizedBox(height: 14),
        _bullets(const [
          'Read PDFs with highlighting and sticky notes',
          'Take bullet notes scoped to each document',
          'Ask questions that are answered from your own documents (RAG)',
          'Generate flashcards from what you study',
          'Stay on pace with a cozy pomodoro timer',
          'Play lofi or your own music while you work',
        ]),

        pw.SizedBox(height: 24),
        _section('Step 1: Import a document'),
        pw.Paragraph(
          text:
              'Use the Import button (or drag a file onto the window) to add '
              'PDFs and images into a notebook. Moonlight Study copies the '
              'file into its own library folder, so you can move the original '
              'afterwards. Each notebook groups related documents.',
        ),

        pw.SizedBox(height: 24),
        _section('Step 2: Choose a model'),
        pw.Paragraph(
          text:
              'From the Models screen, pick a small, efficient model that fits '
              'your machine. The default Qwen2.5-VL-3B can read text AND '
              'images, which lets the app OCR scanned pages automatically. '
              'Models download once over the internet and then never need it '
              'again. Reasoning models (like DeepSeek-R1) show a collapsible '
              '"Thinking" block while they work through problems step by step.',
        ),

        pw.SizedBox(height: 24),
        _section('Step 3: Interact with your material'),
        pw.Paragraph(
          text:
              'Open a document in the reader. Use the tabs on the right to '
              'take notes or ask the assistant questions — answers cite the '
              'sections of your document they came from. Highlight text to '
              'summarize, explain, or copy a selection instantly.',
        ),

        pw.SizedBox(height: 24),
        _section('Study smarter'),
        pw.Paragraph(
          text:
              'After a reading session, generate flashcards from the notes and '
              'text you\'ve studied. Review them on the Flashcards screen. '
              'Plan focused sessions in the Planner and use the pomodoro timer '
              'to pace yourself — each completed session is logged on your '
              'dashboard.',
        ),

        pw.SizedBox(height: 24),
        _section('Privacy & tips'),
        pw.Paragraph(
          text:
              'Everything stays on your device. Your library, notes, '
              'annotations, and settings live in your app data folder. If you '
              'ever need help, check Settings → View logs to export '
              'troubleshooting information.',
        ),
        pw.SizedBox(height: 12),
        pw.Paragraph(
          text:
              'Happy studying — good coffee, good lofi, good learning. ☕',
          style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: _cacao),
        ),
      ],
    ),
  );

  final out = File('assets/docs/getting_started.pdf');
  await out.create(recursive: true);
  await out.writeAsBytes(await doc.save());
  stdout.writeln('Wrote ${out.path}');
}

pw.Widget _section(String title) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: _caramel,
      ),
    ),
  );
}

pw.Widget _bullets(List<String> items) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final item in items)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('•  ', style: pw.TextStyle(color: _caramel)),
              pw.Expanded(
                child: pw.Paragraph(text: item),
              ),
            ],
          ),
        ),
    ],
  );
}