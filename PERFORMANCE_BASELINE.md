# Performance Baseline

Documented on **May 7, 2026**.

## Scope

This baseline documents the current performance shape of:

- Backend query paths for `/api/v1/supervisor/interns`
- Backend query paths used by the student dashboard
- Frontend rendering structure for `StudentDashboardScreen`

This pass is documentation-only. No application code was changed.

## Method And Limits

- Backend query counts below are derived from controller and service structure in `laravel/app/Http/Controllers` and `laravel/app/Services`.
- Frontend rendering metrics below are derived from widget, service, and test structure in `flutter/lib` and `flutter/test`.
- Live runtime profiling was not available in this workspace on May 7, 2026:
  - `laravel/vendor/` is empty, so the Laravel app could not be bootstrapped for an in-process query probe.
  - `flutter` and `dart` are not on `PATH`, so Flutter DevTools and profile-mode frame capture could not run locally.

Treat this report as the current source-based baseline and use it to target the first live profiling pass once the toolchains are restored.

## Baseline Targets

- List endpoints: keep database work under **5 queries** per request.
- Dashboard first render: keep UI thread and raster work under **16 ms per frame** on a 60 Hz target.
- Dashboard data loading: prefer **flat or bounded query counts** and avoid unbounded payload growth for summary views.

## Backend Query Baselines

| Endpoint | Current Baseline | Target | Notes |
| --- | --- | --- | --- |
| `/api/v1/supervisor/interns` | **3 queries** | `<5` | 1 pagination count query, 1 paginated profile query, 1 eager-load query for `student`. Search should stay at 3 because `orWhereHas('student', ...)` is folded into the SQL for the count/page queries instead of adding a separate round-trip. |
| `/api/v1/student/internship` | **2 queries** | `<5` | 1 profile lookup plus 1 eager-load query for `supervisor`. |
| `/api/v1/student/report` | **5 queries** | `<=5` | 1 profile lookup, 1 eager-load query for `student`, 1 eager-load query for `supervisor`, 1 approved-log list query, 1 approved-hours `sum()` query. This hits the target ceiling and duplicates approved-log access for dashboard usage. |
| `/api/v1/student/logs` | **2 queries** | `<5` | 1 profile lookup plus 1 log-list query with `withCount('attachments')`. Query count stays bounded, but payload size grows with total log history. |
| `/api/v1/notifications` | **3 queries** | `<5` | 1 unread-count query, 1 pagination count query, 1 paginated notification-list query. This call is triggered by the dashboard app bar, not by the dashboard body itself. |

## Student Dashboard Load Baseline

`StudentDashboardScreen` currently loads data in two parallel feature areas:

- Dashboard body:
  - `GET /api/v1/student/internship`
  - `GET /api/v1/student/report`
  - `GET /api/v1/student/logs`
- App bar notifications:
  - `GET /api/v1/notifications`

### Initial Request Fan-Out

- Active student with an internship profile:
  - **4 HTTP requests**
  - **12 backend queries total**
  - Query rollup: `2 + 5 + 2 + 3`
- Student without an internship profile:
  - **2 HTTP requests**
  - **5 backend queries total**
  - Query rollup: `2 + 3`

### Load Sequencing

The dashboard body currently performs a request waterfall:

1. Load internship profile
2. If a profile exists, load report
3. If a profile exists, load logs

That means the dashboard summary cannot fully hydrate until all three body requests finish. The notifications button separately starts its own load during widget initialization.

## Frontend Rendering Baseline

### Screen Structure

The loaded student dashboard renders a single scrollable `ListView` with:

- 1 header block
- 5 major content sections:
  - `Next Action`
  - `Internship Summary` and `Internship Status`
  - `Progress and Pace`
  - `Recent Logs`
  - `Quick Actions`
- 4 status metric tiles
- 4 pace tiles
- Up to 4 visible recent-log rows

This is a moderate, bounded widget tree. Layout depth alone is not the main risk area.

### Current Render-Side Metrics

- `Recent Logs` only renders **4 log rows**, which keeps visible widget count bounded.
- The screen still fetches **all** logs from `/api/v1/student/logs`, even though it displays only 4 rows and a handful of aggregates.
- The screen also fetches the full `/api/v1/student/report` payload, even though the dashboard only consumes the report summary fields.

### Current Derived-State Cost

For a fully loaded dashboard build, `_logs` is recomputed repeatedly through getters such as:

- `_pendingHours`
- `_rejectedLogsCount`
- `_pendingLogsCount`
- `_hasTodayLog`
- `_recentLogs`

Based on current getter usage inside `student_dashboard_screen.dart`, a full build triggers roughly:

- **7** pending-hours scans
- **6** pending-log count scans
- **8** today-log checks
- **1** rejected-log count scan
- **3** recent-log projections

That is roughly **25 full or partial list evaluations** over `_logs` per loaded build.

## Bottleneck Signals

The current code structure suggests these are the first bottlenecks to watch:

- **Request waterfall on dashboard mount**
  - The main dashboard body waits for profile, then report, then logs instead of collapsing work into a single summary endpoint or parallelized fetches.
- **Over-fetching for summary UI**
  - `/api/v1/student/report` returns approved log entries plus summary data, but the dashboard only needs the summary.
  - `/api/v1/student/logs` returns full log history, but the dashboard only needs recent activity plus aggregate counters.
- **Hidden notification request**
  - `NotificationBellButton` starts a fetch on mount, so the dashboard screen makes one more request than the body alone suggests.
- **Repeated list derivation during build**
  - The dashboard recomputes log-derived state from `_logs` many times instead of caching derived values per load.

## Current Baseline Summary

### Backend

- `/api/v1/supervisor/interns` is within the desired list-endpoint target at **3 queries**.
- Student dashboard data dependencies expand to **12 backend queries** on a normal first mount when notifications are included.
- Query counts are bounded, but payload size for dashboard data is not bounded by what the UI actually shows.

### Frontend

- The visible widget tree is not unusually deep.
- The stronger risk is data volume and repeated `_logs` recomputation, not raw widget count.
- Use **<16 ms UI** and **<16 ms raster** as the live frame target when Flutter profiling becomes available.

## Follow-Up Runtime Checks

Once the missing toolchains are restored, the first live profiling pass should verify:

1. `StudentDashboardScreen` first-open frame timings in Flutter DevTools (`UI` and `Raster` both under 16 ms).
2. Real query logs for:
   - `/api/v1/supervisor/interns`
   - `/api/v1/student/report`
   - `/api/v1/student/logs`
   - `/api/v1/notifications`
3. Payload size growth as student log history increases.
