# Automated Testing

## Current Baseline

Validated on **May 6, 2026**.

| Suite | Command | Result |
| --- | --- | --- |
| Laravel backend | `docker exec interntrack_app php artisan test` | `175 passed` |
| Flutter frontend | `flutter test` | `78 passed` |
| Combined automated baseline | backend + frontend | `253 passed` |

Production-readiness status: **ready for production promotion based on the current automated validation baseline**.

Non-blocking note:

- The Laravel suite still prints PHPUnit metadata deprecation warnings for `/** @test */` doc-comments. The suite passes today, but those tests should be migrated to attributes before PHPUnit 12.

## Performance Baseline

Source-based performance baselines are documented in `PERFORMANCE_BASELINE.md`.

Performance profiling could not be executed live in this workspace on **May 7, 2026** because:

- `laravel/vendor/` is empty, so the Laravel app cannot be bootstrapped for an in-process query probe.
- `flutter` and `dart` are not on `PATH`, so Flutter profile-mode frame capture cannot run locally.

Use the baseline report to track current query counts, dashboard request fan-out, and render-side bottleneck candidates until the local toolchains are restored.

## Local

Run the full automated suite from the repo root:

```powershell
.\scripts\test-all.ps1
```

Run only backend tests:

```powershell
.\scripts\test-all.ps1 -BackendOnly
```

Run only Flutter tests:

```powershell
.\scripts\test-all.ps1 -FlutterOnly
```

## Environment Notes

- Backend tests use a dedicated Docker MySQL database named `interntrack_test`.
- Backend tests expect the Laravel Docker app container to run as `interntrack_app`.
- Flutter tests need normal access to the local Flutter SDK and cache directories.
- The Laravel Docker bootstrap now creates `.env` from `.env.example` when missing, and the repo includes `.env.testing` for stable automated runs.

If the Laravel containers are not up yet, start them from `laravel/` with:

```powershell
docker compose up -d
```

If you run PHPUnit manually inside Docker, use:

```powershell
docker compose exec mysql mariadb -uroot -psecret -e "CREATE DATABASE IF NOT EXISTS interntrack_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON interntrack_test.* TO 'interntrack_user'@'%'; FLUSH PRIVILEGES;"
docker exec interntrack_app php artisan test
```

## What Changed In This Validation Pass

- Fixed placeholder internship profile handling so adviser assignment and review flows can create partial profiles without schema failures.
- Added a committed Laravel testing environment baseline with `.env.testing` and a safer Docker bootstrap.
- Restored queued email notification behavior and mailable subject/render compatibility for both unit and feature coverage.
- Added a `LogEntryFactory` and stabilized supervisor review transaction coverage around rollback and notification-failure behavior.
- Corrected admin adviser provider imports in Flutter and refreshed the provider/login validation tests to match the current app structure and UX.

## CI

GitHub Actions runs two jobs automatically:

- Laravel tests
- Flutter tests

Workflow:

- `/.github/workflows/test-suite.yml`

## Manual Test Case Coverage

The current manual test-case set in `InternTrack_Test_Cases_Pass_Fail.md` is automated in two layers:

- Laravel PHPUnit feature tests for backend/API behavior
- Flutter widget and unit tests for UI and client logic

Backend modules covered by PHPUnit:

- Authentication and session: `laravel/tests/Feature/AuthFlowTest.php`
- Notifications: `laravel/tests/Feature/NotificationListingTest.php`
- Internship profile: `laravel/tests/Feature/StudentInternshipProfileTest.php`
- Daily time record: `laravel/tests/Feature/StudentDailyTimeRecordTest.php`
- Student logbook and attachments: `laravel/tests/Feature/StudentLogSubmissionTest.php`, `laravel/tests/Feature/StudentAttachmentFlowTest.php`
- Reports and exports: `laravel/tests/Feature/ReportDataEndpointTest.php`, `laravel/tests/Feature/DailyTimeRecordExportTest.php`
- Supervisor review and monitoring: `laravel/tests/Feature/SupervisorDashboardTest.php`, `laravel/tests/Feature/SupervisorLogListingTest.php`, `laravel/tests/Feature/SupervisorLogShowTest.php`, `laravel/tests/Feature/SupervisorLogApprovalTest.php`, `laravel/tests/Feature/SupervisorInternDetailTest.php`
- Adviser intern views: `laravel/tests/Feature/AdviserInternDetailTest.php`
- Admin oversight: `laravel/tests/Feature/AdminDashboardTest.php`, `laravel/tests/Feature/AdminStudentListingTest.php`
- API foundation and hardening: `laravel/tests/Feature/ApiFoundationTest.php`, `laravel/tests/Feature/InputSanitizationTest.php`, `laravel/tests/Feature/SecurityHardeningTest.php`, `laravel/tests/Feature\SecurityHeadersTest.php`

Frontend coverage highlights:

- Auth form validation and login UX
- Student dashboard, log date policy, and reporting models
- Supervisor pending queue and log review flows
- Admin adviser assignment provider behavior
- Shared widgets, notifications, and API config parsing
