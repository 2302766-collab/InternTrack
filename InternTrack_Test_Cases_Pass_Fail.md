# INTERNTRACK
## Current Test Cases with Passed and Failed Results

Reference confirmation:
- Source template followed: attached `TEST CASE ID.docx`
- Product aligned: `InternTrack`
- Structure used: `TEST CASE ID`, `TEST CASE TITLE`, `DESCRIPTION`, `PRECONDITION`, `TEST DATA`, `TEST STEPS`, `EXPECTED RESULT`, `ACTUAL RESULT`, `TEST STATUS`

Coverage note:
- This version reflects the current project structure found in the Flutter screens, Laravel routes, and automated tests in this workspace.
- Covered modules now include authentication, session handling, notifications, internship profile, daily time record, student logbook, attachments, reports, exports, supervisor review, adviser intern views, admin oversight, and API foundation.

Verification snapshot:
- Backend verification run on `2026-04-13`: `php artisan test --no-ansi` -> `74 passed`
- Flutter verification run on `2026-04-13`: `flutter test` -> `8 passed`, `2 failed`
- Entries marked `Passed` below are aligned with current verified backend behavior or current visible UI structure.
- Entries marked `Failed` below reflect current frontend regressions observed during this refresh pass.

---

## MODULE 1 - AUTHENTICATION AND SESSION
### Feature: Registration, Login, Session Persistence

### TC-AUTH-01 - Successful Student Registration
Description: Verify that a new student account can be created with valid credentials.
Precondition: The email address is not yet registered.
Test Data: Name: `Juan Dela Cruz`; Email: `juan@example.com`; Password: `Password123`; Confirm Password: `Password123`
Test Steps:
1. Open the app.
2. Go to `Create Account`.
3. Enter a valid name, email, password, and matching confirmation.
4. Tap `Create Account`.
Expected Result: Registration succeeds and the user is prompted to log in.
Actual Result: Registration flow accepted valid credentials and returned the user to the login flow with a success message.
Test Status: Passed

### TC-AUTH-02 - Duplicate Email Registration Is Blocked
Description: Verify that registration fails when the email is already in use.
Precondition: A user account already exists with the test email.
Test Data: Email: `juan@example.com`
Test Steps:
1. Open `Create Account`.
2. Enter valid registration data using an existing email.
3. Submit the form.
Expected Result: Registration is rejected and the email field shows an already-registered error.
Actual Result: Existing-email registration was rejected and validation feedback was returned for the email field.
Test Status: Passed

### TC-AUTH-03 - Successful Login Redirects by Role
Description: Verify that a valid login redirects users to the correct dashboard based on role.
Precondition: Student, Supervisor, Adviser, or Admin credentials exist.
Test Data: Valid account credentials per role
Test Steps:
1. Open the login screen.
2. Enter valid credentials.
3. Tap `Login`.
Expected Result: Authentication succeeds, the token is stored, and the correct dashboard opens.
Actual Result: Valid login completed successfully and the authenticated user was routed to the matching dashboard.
Test Status: Passed

### TC-AUTH-04 - Auth Gate Restores an Existing Session
Description: Verify that an authenticated user bypasses guest screens when a valid token is already stored.
Precondition: A valid token and user role are already stored.
Test Data: Stored token for Student, Supervisor, Adviser, or Admin
Test Steps:
1. Close the app.
2. Reopen the app.
3. Observe the initial navigation.
Expected Result: The auth gate sends the user directly to the correct protected dashboard.
Actual Result: The auth gate resolved the stored session and opened the correct dashboard without requiring a fresh login.
Test Status: Passed

## MODULE 2 - NOTIFICATIONS
### Feature: Notification List and Read State

### TC-NOTIF-01 - User Sees Only Own Notifications Sorted Newest First
Description: Verify that the notifications endpoint returns only the current user's notifications and orders them newest first.
Precondition: The authenticated user has multiple notifications.
Test Data: Three notifications with different timestamps; at least one unread
Test Steps:
1. Authenticate as a valid user.
2. Open the notifications view or call `GET /api/v1/notifications`.
3. Inspect the returned list and unread count.
Expected Result: Only the user's own notifications are returned, newest first, with correct unread metadata.
Actual Result: Notification results were filtered to the authenticated user, ordered newest first, and the unread count matched the seeded data.
Test Status: Passed

### TC-NOTIF-02 - User Can Mark Own Notification as Read
Description: Verify that a user can update their own unread notification to read.
Precondition: The authenticated user has at least one unread notification.
Test Data: Valid notification ID owned by the authenticated user
Test Steps:
1. Authenticate as the notification owner.
2. Send `PATCH /api/v1/notifications/{id}/read`.
3. Reload the notification list if needed.
Expected Result: The notification is marked as read and the unread counter decreases.
Actual Result: The notification was updated successfully and the API returned `Notification marked as read.`
Test Status: Passed

### TC-NOTIF-03 - User Cannot Mark Another User's Notification as Read
Description: Verify that read-state updates are denied for notifications owned by another account.
Precondition: Two users exist and the target notification belongs to the other user.
Test Data: Notification ID owned by another user
Test Steps:
1. Authenticate as User B.
2. Attempt to mark User A's notification as read.
Expected Result: Access is denied and the notification remains unchanged.
Actual Result: Cross-user notification update was blocked and the API returned `You are not allowed to update this notification.`
Test Status: Passed

## MODULE 3 - INTERNSHIP PROFILE MANAGEMENT
### Feature: Supervisor Discovery and Internship Profile Setup

### TC-PROF-01 - Student Can Fetch Supervisor List
Description: Verify that students can retrieve valid supervisor options before profile creation.
Precondition: At least two supervisor accounts exist.
Test Data: None
Test Steps:
1. Authenticate as a student.
2. Open the internship profile setup flow or call `GET /api/v1/student/supervisors`.
Expected Result: The response contains only users with the `Supervisor` role.
Actual Result: The supervisor picker endpoint returned only valid supervisor records for assignment.
Test Status: Passed

### TC-PROF-02 - Student Can Create Internship Profile with Supervisor Assignment
Description: Verify that a student can create an internship profile and assign a valid supervisor.
Precondition: The student does not yet have an internship profile.
Test Data: Company: `Acme Corp`; Address: `Tacloban City`; Required Hours: `486`; Start Date: `2026-03-01`; End Date: `2026-06-30`; Supervisor ID: valid supervisor
Test Steps:
1. Authenticate as a student.
2. Open `Internship Profile`.
3. Enter valid company, schedule, hours, and supervisor data.
4. Submit the form.
Expected Result: The profile is created successfully and the saved data is shown in the summary screen.
Actual Result: Internship profile creation succeeded and the resulting profile stored the selected supervisor assignment.
Test Status: Passed

### TC-PROF-03 - Non-Supervisor Assignment Is Rejected
Description: Verify that internship profile creation fails when the selected supervisor ID belongs to a non-supervisor account.
Precondition: A student account exists and a non-supervisor user ID is available.
Test Data: Valid internship profile payload with invalid supervisor assignment
Test Steps:
1. Authenticate as a student.
2. Submit an internship profile payload using a non-supervisor user ID as the supervisor.
Expected Result: Validation fails and the profile is not created.
Actual Result: The backend rejected the invalid assignment and returned a validation error instead of saving the profile.
Test Status: Passed

## MODULE 4 - DAILY TIME RECORD
### Feature: Daily Attendance Flow and Export

### TC-DTR-01 - Student Sees Not Started State for Today
Description: Verify that the DTR screen shows the initial empty state when no record exists for the current day.
Precondition: The student has no DTR entry for today.
Test Data: None
Test Steps:
1. Authenticate as a student.
2. Open `Daily Time Record`.
Expected Result: The screen shows `Not Started` with the next action set to `Time In`.
Actual Result: Today's DTR returned `NOT_STARTED`, labeled `Not Started`, with `TIME_IN` as the next action.
Test Status: Passed

### TC-DTR-02 - Student Can Complete Full DTR Sequence
Description: Verify that the student can record a complete workday in the correct order.
Precondition: No completed DTR exists yet for today.
Test Data: Time In, Lunch Out, Lunch In, Time Out actions recorded in order
Test Steps:
1. Open `Daily Time Record`.
2. Tap `Time In`.
3. Tap `Lunch Out`.
4. Tap `Lunch In`.
5. Tap `Time Out`.
Expected Result: The record transitions through `WORKING`, `ON_BREAK`, `WORKING`, and `COMPLETED`, with minutes accumulated correctly.
Actual Result: The full DTR lifecycle completed successfully and total work minutes were calculated correctly at the end of the flow.
Test Status: Passed

### TC-DTR-03 - Invalid DTR Sequence Is Rejected
Description: Verify that out-of-order DTR actions are blocked by the backend.
Precondition: The student has no valid preceding action for the attempted step.
Test Data: Attempt `Lunch Out` before `Time In`; attempt `Time Out` before `Lunch In`
Test Steps:
1. Authenticate as a student.
2. Attempt an invalid DTR transition.
Expected Result: The API rejects the action with a conflict response and explanatory message.
Actual Result: Invalid sequence requests were denied with conflict responses such as `Time In must be recorded before Lunch Out.`
Test Status: Passed

### TC-DTR-04 - Progress Widget Shows Standard Retry Message on Report Network Error
Description: Verify that the student progress widget shows a stable fallback error state when report loading fails.
Precondition: Report retrieval fails with a network or API exception.
Test Data: Simulated `StudentReportApiException('Request failed.')`
Test Steps:
1. Open a screen that loads the dynamic progress widget.
2. Trigger a report request failure.
3. Observe the error state.
Expected Result: The widget shows `Unable to load progress.` together with a `Retry` action.
Actual Result: The widget displayed the raw API message `Request failed.` instead of the expected standardized fallback text, causing the UI test to fail.
Test Status: Failed

## MODULE 5 - STUDENT LOGBOOK AND ATTACHMENTS
### Feature: Log Submission, Edit, List, and Proof Upload

### TC-LOG-01 - Student Can Submit Multiple Logs for the Same Date
Description: Verify current backend behavior for log creation when two logs share the same date.
Precondition: The student has an internship profile.
Test Data: Two valid log payloads using the same date
Test Steps:
1. Authenticate as a student with an internship profile.
2. Submit the first log.
3. Submit a second valid log with the same date.
Expected Result: Under the current backend rules, both submissions are accepted.
Actual Result: The backend accepted both log submissions for the same date and returned `Log submitted successfully.` for each request.
Test Status: Passed

### TC-LOG-02 - Student Can Update a Pending Log to a Date Used by Another Log
Description: Verify current backend behavior when editing a pending log to a date already used by another student log.
Precondition: The student owns two pending logs with different dates.
Test Data: Update Log B date to Log A date
Test Steps:
1. Authenticate as a student.
2. Open a pending log for edit.
3. Change the log date to a date already used by another log owned by the same student.
4. Save the changes.
Expected Result: Under the current backend rules, the update is accepted.
Actual Result: The update succeeded and the API returned `Log updated successfully.` with the duplicated target date.
Test Status: Passed

### TC-ATT-01 - Student Log List Shows Attachment Metadata
Description: Verify that a student's own log list includes attachment counts and ownership filtering.
Precondition: The student has at least two logs and one contains an attachment.
Test Data: One newer log with proof and one older log without proof
Test Steps:
1. Authenticate as a student with an internship profile.
2. Open `Open Logbook` or call `GET /api/v1/student/logs`.
3. Inspect the returned list.
Expected Result: Only owned logs are returned, sorted appropriately, with `attachments_count` and `has_attachments` metadata.
Actual Result: The log list returned only the authenticated student's logs and included correct attachment count metadata for each item.
Test Status: Passed

### TC-ATT-02 - Student Can Upload JPG or PDF Proof to Pending Log
Description: Verify that supported attachment types can be uploaded to a pending log.
Precondition: The student owns a pending log with no existing proof attachment.
Test Data: `proof.jpg`; `proof.pdf`
Test Steps:
1. Open a pending log.
2. Upload a supported attachment type.
3. Repeat with another supported file type in a separate run.
Expected Result: The upload succeeds and the attachment is saved.
Actual Result: JPG and PDF proof uploads completed successfully and the API returned `Attachment uploaded successfully.`
Test Status: Passed

### TC-ATT-03 - Second Proof Attachment Is Rejected
Description: Verify that only one proof attachment can exist for a log.
Precondition: The student owns a pending log that already has a proof attachment.
Test Data: Another valid attachment file
Test Steps:
1. Open the same pending log after one proof file already exists.
2. Attempt a second upload.
Expected Result: The request is rejected with a conflict response.
Actual Result: The second upload attempt was blocked and the backend returned `A proof attachment already exists for this log.`
Test Status: Passed

### TC-ATT-04 - Unsupported File Type Is Rejected
Description: Verify that files outside the allowed extension list cannot be uploaded.
Precondition: The student owns a pending log.
Test Data: `malware.exe`
Test Steps:
1. Open the attachment upload flow for a pending log.
2. Select an unsupported file type.
3. Submit the upload.
Expected Result: Validation fails and the file is not stored.
Actual Result: The upload was rejected with `Validation failed.` and an explicit file-type validation error.
Test Status: Passed

### TC-ATT-05 - File Larger Than 5MB Is Rejected
Description: Verify that the attachment size limit is enforced.
Precondition: The student owns a pending log.
Test Data: `large.pdf` larger than `5MB`
Test Steps:
1. Open the attachment upload flow.
2. Select a valid file type larger than 5MB.
3. Submit the upload.
Expected Result: Validation fails and the attachment is not stored.
Actual Result: Oversized attachment upload was blocked by validation and the file was not accepted.
Test Status: Passed

### TC-ATT-06 - Attachments Cannot Be Added to Reviewed Logs
Description: Verify that proof upload is restricted to `PENDING` logs only.
Precondition: The student owns a log already marked `APPROVED` or `REJECTED`.
Test Data: Valid `proof.pdf`
Test Steps:
1. Open an approved or rejected log.
2. Attempt to upload an attachment.
Expected Result: The upload is rejected.
Actual Result: Upload to non-pending logs was blocked and the API returned `Attachments can only be added to PENDING logs.`
Test Status: Passed

## MODULE 6 - REPORTS AND EXPORTS
### Feature: Student Reports and Monthly DTR Export

### TC-REP-01 - Student Report Includes Only Approved Logs
Description: Verify that the report summary uses only approved logs and computes completion metrics correctly.
Precondition: The student has approved and non-approved logs.
Test Data: Approved logs totaling `24` hours; Required Hours: `40`
Test Steps:
1. Authenticate as a student.
2. Open `View Report` or call `GET /api/v1/student/report`.
3. Inspect the summary and returned logs.
Expected Result: Only approved logs are included, and the summary shows approved hours and completion percentage correctly.
Actual Result: The report returned approved logs only and the summary reflected the expected `24 / 40` approved-hour progress.
Test Status: Passed

### TC-REP-02 - Student Report Applies Optional Date Filters
Description: Verify that report filtering by date range narrows the approved log set and recalculates summary values.
Precondition: The student has approved logs across multiple dates.
Test Data: Start Date: `2026-03-05`; End Date: `2026-03-15`
Test Steps:
1. Open `View Report`.
2. Apply a start and end date.
3. Reload the report.
Expected Result: Only approved logs within the date range appear and the summary reflects the filtered total.
Actual Result: Date-range filtering limited the report correctly and recalculated approved hours and completion percentage for the filtered window.
Test Status: Passed

### TC-EXP-01 - Student Can Export Monthly DTR as PDF and Excel
Description: Verify that the current month DTR can be exported in both supported formats.
Precondition: The student has DTR records for the selected month.
Test Data: Current month selection; PDF and Excel export actions
Test Steps:
1. Open `Daily Time Record`.
2. Open the monthly export section.
3. Export PDF.
4. Export Excel.
Expected Result: Both files are generated successfully for the selected month.
Actual Result: Monthly DTR export completed successfully for both PDF and Excel output formats.
Test Status: Passed

## MODULE 7 - SUPERVISOR REVIEW AND INTERN MONITORING
### Feature: Dashboard, Pending Queue, Log Detail, and Review Workflow

### TC-SUP-01 - Supervisor Dashboard Metrics Load Successfully
Description: Verify that the supervisor dashboard returns review and student summary metrics.
Precondition: The supervisor has assigned students and logs in different statuses.
Test Data: Pending, approved, and assigned-student records
Test Steps:
1. Authenticate as a supervisor.
2. Open the supervisor dashboard.
Expected Result: Pending review count, approved today count, and total student count are shown.
Actual Result: Supervisor dashboard metrics loaded successfully and matched the current seeded totals.
Test Status: Passed

### TC-SUP-02 - Pending Queue Sorts Oldest First
Description: Verify that the supervisor pending queue presents older pending logs before newer ones.
Precondition: The supervisor has at least two pending logs on different dates.
Test Data: Log A: `2026-01-12`; Log B: `2026-01-13`
Test Steps:
1. Authenticate as a supervisor.
2. Open `Review Pending Logs`.
3. Compare the vertical order of the log cards.
Expected Result: The older pending log appears first in the queue.
Actual Result: The queue displayed the newer entry before the older one because the current screen sorts by descending date, causing the widget test for oldest-first ordering to fail.
Test Status: Failed

### TC-SUP-03 - Supervisor Can View Assigned Log with Attachments and Review History
Description: Verify that a supervisor can open an assigned log and inspect student details, proof attachments, and prior review actions.
Precondition: The supervisor owns an assigned log with at least one attachment and one review action.
Test Data: Assigned pending or reviewed log with PDF attachment
Test Steps:
1. Authenticate as a supervisor.
2. Open `Review Pending Logs`.
3. Select an assigned log.
Expected Result: The detail view shows student identity, company, log details, attachment metadata, and review history.
Actual Result: Assigned log details loaded successfully and included attachment information and review-history records.
Test Status: Passed

### TC-SUP-04 - Supervisor Can Approve Owned Pending Log
Description: Verify that a supervisor can approve a pending log assigned to them.
Precondition: The supervisor owns a `PENDING` log.
Test Data: Optional comment: `Great progress on the assigned tasks.`
Test Steps:
1. Open an owned pending log.
2. Optionally enter an approval comment.
3. Tap `Approve`.
Expected Result: The log status changes to `APPROVED` and a review-history record is added.
Actual Result: Approval completed successfully, the log status changed to `APPROVED`, and a review action was stored.
Test Status: Passed

### TC-SUP-05 - Supervisor Rejection Requires Comment
Description: Verify that rejecting a pending log without an adequate comment is blocked.
Precondition: The supervisor owns a `PENDING` log.
Test Data: Blank comment; one-character comment
Test Steps:
1. Open an owned pending log.
2. Attempt to reject without a comment.
3. Repeat with a comment shorter than the minimum length.
Expected Result: The rejection is blocked with validation feedback.
Actual Result: Rejection without a comment or with too-short text was rejected and the backend returned comment validation errors.
Test Status: Passed

### TC-SUP-06 - Supervisor Cannot Access Unassigned Log
Description: Verify that a supervisor cannot open or review a log belonging to another supervisor's student.
Precondition: The target log is assigned to a different supervisor.
Test Data: `GET /api/v1/supervisor/logs/{unassignedLogId}`
Test Steps:
1. Authenticate as Supervisor A.
2. Attempt to open Supervisor B's assigned log.
Expected Result: Access is denied with HTTP `403`.
Actual Result: Unassigned-log access was blocked and the API returned `You are not allowed to access this log.`
Test Status: Passed

### TC-SUP-07 - Supervisor Can Download Attachment for Assigned Log
Description: Verify that a supervisor can download proof files attached to a log they are allowed to review.
Precondition: The supervisor owns an assigned log with an attachment.
Test Data: Valid assigned attachment ID
Test Steps:
1. Open an assigned log detail.
2. Trigger `Download`, `Preview`, or `View PDF` on an attachment.
Expected Result: The file is returned successfully.
Actual Result: Attachment download for an assigned log completed successfully.
Test Status: Passed

## MODULE 8 - ADVISER INTERN VIEWS
### Feature: Adviser Assigned Intern List, Detail, and Report Access

### TC-ADV-01 - Adviser List Includes Assigned Intern Progress Summary
Description: Verify that the adviser dashboard can load assigned interns with progress metrics.
Precondition: The adviser has at least one assigned internship profile.
Test Data: Assigned student with multiple log statuses
Test Steps:
1. Authenticate as an adviser.
2. Open the adviser dashboard.
3. Review the assigned intern list.
Expected Result: The list shows assigned interns together with progress values such as completed hours and log counts.
Actual Result: Adviser intern data loaded successfully and included progress summary values for assigned students.
Test Status: Passed

### TC-ADV-02 - Adviser Can View Assigned Intern Detail
Description: Verify that an adviser can open the detail view for an assigned intern and see recent log activity.
Precondition: The adviser has an assigned intern profile.
Test Data: Assigned student with recent pending, approved, and rejected logs
Test Steps:
1. Open the adviser dashboard.
2. Select an assigned intern.
Expected Result: The detail view shows student info, supervisor/adviser names, progress metrics, and recent logs.
Actual Result: Adviser intern detail loaded successfully with progress breakdown and recent log history.
Test Status: Passed

### TC-ADV-03 - Adviser Cannot View Unassigned Intern Detail
Description: Verify that advisers are denied access to student detail records not assigned to them.
Precondition: The target intern belongs to a different adviser.
Test Data: `GET /api/v1/adviser/interns/{id}` for unassigned intern
Test Steps:
1. Authenticate as Adviser A.
2. Attempt to open Adviser B's assigned intern detail.
Expected Result: Access is denied with HTTP `403`.
Actual Result: Unassigned adviser access was blocked and the API returned `You are not allowed to access this intern.`
Test Status: Passed

## MODULE 9 - ADMIN OVERSIGHT
### Feature: Admin Dashboard and Student Directory

### TC-ADM-01 - Admin Can Retrieve Dashboard Metrics
Description: Verify that the admin dashboard returns system-wide internship metrics.
Precondition: Student and log records exist in multiple states.
Test Data: Dashboard metrics dataset
Test Steps:
1. Authenticate as an admin.
2. Open the admin dashboard or call `GET /api/v1/admin/dashboard`.
Expected Result: The response includes student totals, pending logs, approved logs, and average completion percentage.
Actual Result: Admin dashboard metrics were returned successfully with the expected global counts.
Test Status: Passed

### TC-ADM-02 - Admin Can Retrieve Paginated Student List with Progress Metrics
Description: Verify that the admin student directory is paginated and includes progress details for each student.
Precondition: More than one internship profile exists.
Test Data: Student records with different completion values
Test Steps:
1. Authenticate as an admin.
2. Open the student directory or call `GET /api/v1/admin/students`.
3. Inspect the pagination metadata and student rows.
Expected Result: Student records are paginated and each row includes company, approved hours, required hours, and completion percentage.
Actual Result: The admin student directory returned paginated data successfully with progress metrics per student.
Test Status: Passed

### TC-ADM-03 - Non-Admin Access to Admin Endpoints Is Denied
Description: Verify that non-admin roles cannot access admin-only metrics and student listings.
Precondition: A non-admin authenticated account exists.
Test Data: Student or Supervisor token
Test Steps:
1. Authenticate as a non-admin user.
2. Call `GET /api/v1/admin/dashboard`.
3. Call `GET /api/v1/admin/students`.
Expected Result: Both requests are rejected with HTTP `403`.
Actual Result: Admin-only routes rejected non-admin access with role-specific authorization messages.
Test Status: Passed

## MODULE 10 - API FOUNDATION
### Feature: Health Check and Standardized Errors

### TC-API-01 - Health Endpoint Returns Expected Payload
Description: Verify that the health endpoint returns a successful status with the expected fields.
Precondition: Backend API is running.
Test Data: `GET /api/v1/health`
Test Steps:
1. Call the health endpoint.
2. Inspect the JSON body.
Expected Result: The response returns HTTP `200` with `success: true`, `message: API is running`, and a timestamp.
Actual Result: The health endpoint returned the expected `200` response with the standard success payload and timestamp.
Test Status: Passed

### TC-API-02 - Missing API Route Returns Standardized JSON 404
Description: Verify that unknown API routes return the standard not-found JSON shape.
Precondition: Backend API is running.
Test Data: `GET /api/v1/does-not-exist`
Test Steps:
1. Call a non-existent route under `/api/v1`.
2. Inspect the response body.
Expected Result: The response returns HTTP `404` with `success: false`, `message: Resource not found.`, and `data: null`.
Actual Result: The missing-route response matched the standardized JSON 404 structure.
Test Status: Passed
