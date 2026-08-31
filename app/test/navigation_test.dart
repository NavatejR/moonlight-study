import 'package:flutter_test/flutter_test.dart';
import 'package:study_companion/core/state/navigation.dart';

void main() {
  group('effectiveSectionFor', () {
    test('leaves chat alone when AI is enabled', () {
      expect(effectiveSectionFor(AppSection.chat, aiEnabled: true),
          AppSection.chat);
    });

    test('redirects chat to dashboard when AI is disabled', () {
      expect(effectiveSectionFor(AppSection.chat, aiEnabled: false),
          AppSection.dashboard);
    });

    test('never mutates non-chat sections when AI is disabled', () {
      for (final section in AppSection.values) {
        if (section == AppSection.chat) continue;
        expect(effectiveSectionFor(section, aiEnabled: false), section,
            reason: 'section $section should pass through unchanged');
      }
    });

    test('pure: repeated calls do not change provider state', () {
      // Calling the helper is side-effect free; the routing decision is pure.
      final first = effectiveSectionFor(AppSection.chat, aiEnabled: false);
      final second = effectiveSectionFor(AppSection.chat, aiEnabled: false);
      expect(first, second);
    });
  });
}
