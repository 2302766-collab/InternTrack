# InternTrack Flutter Client

## Current Validation Baseline

Validated on **May 6, 2026** with:

```powershell
flutter test
```

Result: **78 tests passed**.

## Package

- Package name: `intern_track_app`
- Flutter: `3.38.7`
- Dart: `3.10.7`

## Common Commands

Run the frontend test suite:

```powershell
flutter test
```

Run a single test file:

```powershell
flutter test test/login_form_validation_test.dart
```

## Notes From The Latest Validation Pass

- Fixed the admin adviser provider imports so the provider test can compile against the current project structure.
- Reworked the adviser provider test to use a lightweight fake service instead of an unavailable mocking package.
- Updated the login validation tests to match the current UX:
  the submit button stays disabled while the form is invalid, and field-level validation appears through user interaction.
