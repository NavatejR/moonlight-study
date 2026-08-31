---
name: Pull request
about: Submit changes to Moonlight Study
title: ""
labels: ""
assignees: ""
---

Thank you for contributing! Please make sure the following checklist is complete
before requesting review.

## Summary
<!-- What does this PR do, and why? Keep it focused — one logical change per PR. -->

- Closes #[issue]

## Changes
<!-- Bullet-list the key changes. -->

- 

## Testing
<!-- How did you verify this change? Paste the relevant commands + output. -->
```bash
cd app
flutter analyze
flutter test test/navigation_test.dart test/pomodoro_test.dart test/latex_syntax_test.dart
```

- [ ] `flutter analyze` passes with no issues
- [ ] Fast unit tests pass
- [ ] Regenerated drift codegen (if `app_database.dart` changed) and committed `app_database.g.dart`
- [ ] Updated docs/README if user-facing behavior changed

## Screenshots (if applicable)
<!-- Add screenshots for UI changes. -->

## Additional context
<!-- Anything else reviewers should know. -->
