import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_companion/core/db/app_database.dart';
import 'package:study_companion/features/onboarding/onboarding_screen.dart';

import 'helpers/test_db.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
  }

  setUp(() async {
    db = await openInMemoryDb();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
  });

  testWidgets('renders the welcome page with tutorial controls', (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Skip tutorial'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Moonlight Study'), findsWidgets);
  });

  testWidgets('Next advances through pages to Get started', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // Page 2 shows the recommended model for this device.
    expect(find.textContaining('Recommended: '), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // Final page switches the primary button to "Get started".
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('final page explains offline workflow', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Ready when you are.'), findsOneWidget);
    expect(find.textContaining('Replay tutorial'), findsOneWidget);
  });

  testWidgets('starting the tutorial shows an importing spinner', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Skip tutorial'));
    // The import step flips the button into a busy spinner in the same frame;
    // don't pumpAndSettle here because the import I/O never resolves in tests.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}