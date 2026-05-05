# Automated Testing

This project now has a single local command for the current backend and Flutter test suites, plus a GitHub Actions workflow for every push and pull request.

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

Notes:

- Backend tests use a dedicated Docker MySQL database named `interntrack_test`.
- Backend tests expect the Laravel Docker app container to be running as `interntrack_app`.
- If the Laravel containers are not up yet, start them from `laravel/` with:

```powershell
docker compose up -d
```

- The bundled test script will create `interntrack_test` automatically before running PHPUnit.
- If you run PHPUnit manually inside Docker, use:

```powershell
docker compose exec mysql mariadb -uroot -psecret -e "CREATE DATABASE IF NOT EXISTS interntrack_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON interntrack_test.* TO 'interntrack_user'@'%'; FLUSH PRIVILEGES;"
docker compose exec app php artisan test
```

## CI

GitHub Actions runs two jobs automatically:

- Laravel tests
- Flutter tests

The workflow file is:

`/.github/workflows/test-suite.yml`

## Manual Test Case Coverage

The current manual test-case set in `InternTrack_Test_Cases_Pass_Fail.md` is automated in two layers:

- Laravel PHPUnit feature tests for backend/API behavior
- Flutter widget tests for UI-only behavior

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
- API foundation: `laravel/tests/Feature/ApiFoundationTest.php`

Frontend-only manual cases are not suitable for PHPUnit and should stay under Flutter tests:

- Progress widget fallback messaging
- Supervisor pending queue visual ordering and navigation behavior
