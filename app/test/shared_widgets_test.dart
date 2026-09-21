import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_companion/core/theme/app_theme.dart';
import 'package:study_companion/shared/widgets/empty_state.dart';
import 'package:study_companion/shared/widgets/error_state.dart';
import 'package:study_companion/shared/widgets/loading_skeleton.dart';

Future<void> pumpInApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
  );
}

void main() {
  group('EmptyState', () {
    testWidgets('shows title, message and icon', (tester) async {
      await pumpInApp(
        tester,
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'No documents',
          message: 'Import a PDF to get started.',
        ),
      );

      expect(find.text('No documents'), findsOneWidget);
      expect(find.text('Import a PDF to get started.'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('renders the action button and calls back', (tester) async {
      var tapped = false;
      await pumpInApp(
        tester,
        EmptyState(
          icon: Icons.folder_open_outlined,
          title: 'No notebooks',
          message: 'Create your first notebook.',
          actionLabel: 'New notebook',
          onAction: () => tapped = true,
        ),
      );

      expect(find.text('New notebook'), findsOneWidget);
      await tester.tap(find.text('New notebook'));
      expect(tapped, isTrue);
    });
  });

  group('ErrorState', () {
    testWidgets('maps a known error to a friendly message', (tester) async {
      await pumpInApp(
        tester,
        const ErrorState(error: FormatException('bad pdf')),
      );
      expect(find.textContaining('Invalid file format'), findsOneWidget);
    });

    testWidgets('shows retry button only when onRetry is set', (tester) async {
      var retries = 0;
      await pumpInApp(
        tester,
        ErrorState(
          error: Exception('x'),
          onRetry: () => retries++,
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('no retry button when handler is absent', (tester) async {
      await pumpInApp(tester, const ErrorState(error: FormatException('bad')));
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('LoadingSkeleton', () {
    testWidgets('renders shimmer bars', (tester) async {
      await pumpInApp(
        tester,
        Column(
          children: [
            const LoadingSkeleton(),
            const NotebookCardSkeleton(),
            SizedBox(
              height: 220,
              child: ListSkeleton(
                itemCount: 2,
                itemBuilder: (_, _) => const LoadingSkeleton(),
              ),
            ),
          ],
        ),
      );

      // Skeletons render as rounded containers; the shimmer effect stays alive.
      expect(find.byType(LoadingSkeleton), findsWidgets);
      expect(find.byType(NotebookCardSkeleton), findsOneWidget);
    });

    testWidgets('empty list skeleton emits no items', (tester) async {
      await pumpInApp(
        tester,
        ListSkeleton(itemCount: 0, itemBuilder: (_, _) => const SizedBox()),
      );
      expect(find.byType(LoadingSkeleton), findsNothing);
    });
  });
}