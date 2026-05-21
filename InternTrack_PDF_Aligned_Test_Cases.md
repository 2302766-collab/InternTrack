# INTERNTRACK
## PDF-Aligned Manual Test Cases for Current System

Purpose:
- This document converts the uploaded PDF test set into a version that matches the current InternTrack Flutter and Laravel implementation in this workspace.
- It keeps the same overall module coverage while correcting labels, payload assumptions, and route behavior where the PDF was too generic.

Key alignment fixes:
- Registration uses `First Name`, `Last Name`, and `Gender`, and the submit button label is `Create Account`.
- Profile photo updates are handled through `avatar_base64` on `PATCH /api/v1/auth/avatar`, not a raw multipart filename-based upload contract.
- Protected route behavior is enforced by Flutter route guards and Laravel role middleware.
- DTR, reports, exports, edit requests, notifications, and assignments follow the `/api/v1/...` routes in the current backend.

Status note:
- `Actual Result` is intentionally set to `Pending execution`.
- `Test Status` is intentionally set to `Not Run`.

---

## MODULE 1 - AUTHENTICATION AND SESSION

### TC-AUTH-01
Test Case ID: TC-AUTH-01
Test Case Title: Successful Student Registration
Description: Verify that a new student can register using valid data.
Precondition: The email address is not yet registered.
Test Data: First Name `Juan`; Last Name `Dela Cruz`; Gender `Male`; Email `juan@example.com`; Password `Password123`; Confirm Password `Password123`
Test Steps:
1. Open the app.
2. Navigate to `Create Account`.
3. Enter valid first name, last name, gender, email, password, and confirmation.
4. Tap `Create Account`.
Expected Result: Registration succeeds, a success message is shown, and the user is redirected to the login screen.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-02
Test Case ID: TC-AUTH-02
Test Case Title: Registration Using Existing Email
Description: Verify that registration fails when the email is already used.
Precondition: An existing account already uses `juan@example.com`.
Test Data: First Name `Juan`; Last Name `Dela Cruz`; Gender `Male`; Email `juan@example.com`; Password `Password123`
Test Steps:
1. Open the registration screen.
2. Enter valid values using an existing email.
3. Tap `Create Account`.
Expected Result: Registration is rejected and an email-already-exists validation message is shown.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-03
Test Case ID: TC-AUTH-03
Test Case Title: Registration with Invalid Email Format
Description: Verify that registration does not allow an invalid email format.
Precondition: User is on the registration form.
Test Data: Email `juanexample.com`
Test Steps:
1. Fill in valid first name, last name, and gender.
2. Enter an invalid email format.
3. Enter valid password fields.
4. Attempt to submit the form.
Expected Result: The form is not submitted and the email field shows validation feedback.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-04
Test Case ID: TC-AUTH-04
Test Case Title: Registration with Blank Required Fields
Description: Verify that registration fails when required fields are blank.
Precondition: User is on the registration form.
Test Data: Blank first name or blank last name or blank email or blank password
Test Steps:
1. Open `Create Account`.
2. Leave one or more required fields empty.
3. Attempt to tap `Create Account`.
Expected Result: Validation errors are shown and registration is blocked.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-05
Test Case ID: TC-AUTH-05
Test Case Title: Registration with Short Password
Description: Verify that registration rejects a password shorter than the minimum required length.
Precondition: User is on the registration form.
Test Data: Password `Pass12`; Confirm Password `Pass12`
Test Steps:
1. Enter valid first name, last name, gender, and email.
2. Enter a short password.
3. Attempt to submit the form.
Expected Result: Registration is blocked and a password-length validation message is shown.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-06
Test Case ID: TC-AUTH-06
Test Case Title: Registration with Password Mismatch
Description: Verify that registration fails when password and confirmation do not match.
Precondition: User is on the registration form.
Test Data: Password `Password123`; Confirm Password `Password124`
Test Steps:
1. Enter valid first name, last name, gender, and email.
2. Enter mismatched password values.
3. Attempt to submit the form.
Expected Result: Registration is blocked and a password-mismatch message is shown.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-07
Test Case ID: TC-AUTH-07
Test Case Title: Successful Login
Description: Verify that a valid user can log in successfully.
Precondition: A registered user account exists.
Test Data: Email `student@example.com`; Password `Password123`
Test Steps:
1. Open the login screen.
2. Enter valid credentials.
3. Tap `Login`.
Expected Result: Login succeeds and the user is redirected to the correct dashboard for the role.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-08
Test Case ID: TC-AUTH-08
Test Case Title: Login with Wrong Password
Description: Verify that login fails when the password is incorrect.
Precondition: A registered user account exists.
Test Data: Email `student@example.com`; Password `WrongPass123`
Test Steps:
1. Open the login screen.
2. Enter a valid email and incorrect password.
3. Tap `Login`.
Expected Result: Login fails and an `Invalid credentials` message is shown.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-09
Test Case ID: TC-AUTH-09
Test Case Title: Login with Unregistered Email
Description: Verify that login fails when the email is not registered.
Precondition: The test email does not exist in the system.
Test Data: Email `nouser@example.com`; Password `Password123`
Test Steps:
1. Open the login screen.
2. Enter an unregistered email and a valid password format.
3. Tap `Login`.
Expected Result: Login is rejected and the user remains on the login screen.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-10
Test Case ID: TC-AUTH-10
Test Case Title: Restore Session on App Relaunch
Description: Verify that an authenticated session is restored after reopening the app.
Precondition: A valid token is stored locally.
Test Data: Existing active session
Test Steps:
1. Log in successfully.
2. Close the app completely.
3. Reopen the app.
Expected Result: The app bypasses guest pages and opens the correct protected dashboard.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-11
Test Case ID: TC-AUTH-11
Test Case Title: Logout Clears Session
Description: Verify that logout removes the current authenticated session.
Precondition: User is logged in.
Test Data: Valid active session
Test Steps:
1. Tap the logout action.
2. Attempt to reopen a protected page.
Expected Result: The session is cleared and the user is returned to the login screen.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-12
Test Case ID: TC-AUTH-12
Test Case Title: Protected Route Access After Logout
Description: Verify that a logged-out user cannot access protected routes using refresh or manual route entry.
Precondition: User has already logged out.
Test Data: Protected route such as `/student-dashboard` or `/settings`
Test Steps:
1. Logout from the app.
2. Try to reopen a protected route directly.
Expected Result: Access is denied and the login screen is shown.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 2 - ACCOUNT PROFILE AND SETTINGS

### TC-ACC-01
Test Case ID: TC-ACC-01
Test Case Title: View Current User Profile
Description: Verify that a logged-in user can view their profile information.
Precondition: User is authenticated.
Test Data: Any valid account
Test Steps:
1. Log in to the app.
2. Open the dashboard profile area or account section.
3. Load account data.
Expected Result: The correct user profile information is displayed.
Actual Result: Pending execution
Test Status: Not Run

### TC-ACC-02
Test Case ID: TC-ACC-02
Test Case Title: Update User Profile
Description: Verify that a user can update editable profile fields.
Precondition: User is authenticated.
Test Data: Updated name `Juan Updated`; Gender `Male`
Test Steps:
1. Open the profile editing flow.
2. Edit the user profile fields.
3. Save the changes.
4. Reload the screen.
Expected Result: The profile updates are saved and displayed correctly.
Actual Result: Pending execution
Test Status: Not Run

### TC-ACC-03
Test Case ID: TC-ACC-03
Test Case Title: Update Profile with Blank Name
Description: Verify that the profile update is blocked when a required field like name is blank.
Precondition: User is on the profile update screen.
Test Data: Blank name
Test Steps:
1. Delete the current name value.
2. Tap save.
Expected Result: The update is blocked and a validation message is shown.
Actual Result: Pending execution
Test Status: Not Run

### TC-ACC-04
Test Case ID: TC-ACC-04
Test Case Title: Update Profile Photo with Valid Base64 Image
Description: Verify that a valid profile photo can be updated successfully using the current API contract.
Precondition: User is authenticated.
Test Data: Valid image selected in the UI and converted to `avatar_base64`
Test Steps:
1. Open the profile photo update control.
2. Choose a valid image file from the device.
3. Submit the photo update.
Expected Result: The profile photo is updated and displayed in the app.
Actual Result: Pending execution
Test Status: Not Run

### TC-ACC-05
Test Case ID: TC-ACC-05
Test Case Title: Reject Oversized Profile Photo
Description: Verify that profile photo updates larger than 5MB are rejected.
Precondition: User is authenticated.
Test Data: Oversized image converted to `avatar_base64`
Test Steps:
1. Open the profile photo update control.
2. Select an image larger than 5MB.
3. Submit the update.
Expected Result: The update is rejected and an error is shown stating the profile photo must be 5MB or smaller.
Actual Result: Pending execution
Test Status: Not Run

### TC-ACC-06
Test Case ID: TC-ACC-06
Test Case Title: Persist Theme Preference
Description: Verify that theme preference remains saved after app restart.
Precondition: Settings screen is accessible.
Test Data: Theme mode `Dark`
Test Steps:
1. Open `Settings`.
2. Turn on `Dark Mode`.
3. Close and reopen the app.
Expected Result: The chosen theme remains active after relaunch.
Actual Result: Pending execution
Test Status: Not Run

### TC-ACC-07
Test Case ID: TC-ACC-07
Test Case Title: Access Settings While Logged Out
Description: Verify that a logged-out user cannot access settings.
Precondition: User is not authenticated.
Test Data: Settings route
Test Steps:
1. Open the settings route directly while logged out.
Expected Result: The user is redirected to the login screen.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 3 - NOTIFICATIONS

### TC-NOTIF-01
Test Case ID: TC-NOTIF-01
Test Case Title: View Notification List
Description: Verify that a user can view their own notifications.
Precondition: The user has existing notifications.
Test Data: Read and unread notifications
Test Steps:
1. Log in to the app.
2. Open the notification list.
Expected Result: Only the current user's notifications are displayed, ordered by newest first.
Actual Result: Pending execution
Test Status: Not Run

### TC-NOTIF-02
Test Case ID: TC-NOTIF-02
Test Case Title: Notification List When No Notifications Exist
Description: Verify that the app handles an empty notification list correctly.
Precondition: The user has no notifications.
Test Data: Empty notification set
Test Steps:
1. Log in as a user with no notifications.
2. Open the notification list.
Expected Result: The app shows an empty state without errors.
Actual Result: Pending execution
Test Status: Not Run

### TC-NOTIF-03
Test Case ID: TC-NOTIF-03
Test Case Title: Mark Owned Notification as Read
Description: Verify that the user can mark their own notification as read.
Precondition: The user has an unread notification.
Test Data: Valid owned notification ID
Test Steps:
1. Open the notification list.
2. Mark an unread owned notification as read.
Expected Result: The notification read state is updated successfully.
Actual Result: Pending execution
Test Status: Not Run

### TC-NOTIF-04
Test Case ID: TC-NOTIF-04
Test Case Title: Mark Other User Notification as Read
Description: Verify that a user cannot update another user's notification.
Precondition: Another user's notification ID is known.
Test Data: Notification ID owned by another account
Test Steps:
1. Authenticate as User B.
2. Attempt to mark User A's notification as read using `PATCH /api/v1/notifications/{id}/read`.
Expected Result: Access is denied and the notification remains unchanged.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 4 - INTERNSHIP PROFILE

### TC-PROF-01
Test Case ID: TC-PROF-01
Test Case Title: Create Internship Profile Successfully
Description: Verify that a student can create an internship profile with valid data.
Precondition: Student is logged in and has no existing profile.
Test Data: Company `Acme Corp`; Address `Tacloban City`; Required Hours `486`; Start Date `2026-03-01`; End Date `2026-06-30`
Test Steps:
1. Open `Internship Profile`.
2. Enter valid profile details.
3. Submit the form.
Expected Result: The profile is created successfully and displayed in the app.
Actual Result: Pending execution
Test Status: Not Run

### TC-PROF-02
Test Case ID: TC-PROF-02
Test Case Title: View Existing Internship Profile
Description: Verify that a student can retrieve their saved internship profile.
Precondition: Student already has a saved internship profile.
Test Data: Existing profile
Test Steps:
1. Open `Internship Profile`.
2. Load the current profile data.
Expected Result: The saved internship profile is displayed correctly.
Actual Result: Pending execution
Test Status: Not Run

### TC-PROF-03
Test Case ID: TC-PROF-03
Test Case Title: Create Internship Profile with Invalid Required Hours
Description: Verify that required hours must be greater than zero.
Precondition: Student is on the internship profile form.
Test Data: Required Hours `0`
Test Steps:
1. Enter otherwise valid internship profile data.
2. Set required hours to zero.
3. Submit the form.
Expected Result: Validation fails and the profile is not saved.
Actual Result: Pending execution
Test Status: Not Run

### TC-PROF-04
Test Case ID: TC-PROF-04
Test Case Title: Create Internship Profile with End Date Before Start Date
Description: Verify that the end date must be after the start date.
Precondition: Student is on the internship profile form.
Test Data: Start Date `2026-06-30`; End Date `2026-03-01`
Test Steps:
1. Enter otherwise valid internship profile data.
2. Set an end date earlier than the start date.
3. Submit the form.
Expected Result: Validation fails and the profile is not saved.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 5 - DAILY TIME RECORD

### TC-DTR-01
Test Case ID: TC-DTR-01
Test Case Title: View Not Started DTR State
Description: Verify that the DTR screen shows the initial state when no record exists for the current day.
Precondition: Student has no DTR entry for today.
Test Data: None
Test Steps:
1. Open `Daily Time Record`.
Expected Result: The screen shows `Not Started` and the next action is `Time In`.
Actual Result: Pending execution
Test Status: Not Run

### TC-DTR-02
Test Case ID: TC-DTR-02
Test Case Title: Complete Full DTR Sequence
Description: Verify that a student can complete the expected DTR action flow.
Precondition: Student is logged in.
Test Data: Current day record
Test Steps:
1. Tap `Time In`.
2. Tap `Lunch Out`.
3. Tap `Lunch In`.
4. Tap `Time Out`.
Expected Result: The full DTR sequence is accepted and the record status is updated correctly.
Actual Result: Pending execution
Test Status: Not Run

### TC-DTR-03
Test Case ID: TC-DTR-03
Test Case Title: Invalid DTR Sequence Is Rejected
Description: Verify that out-of-order DTR actions are blocked.
Precondition: Student has not yet started the correct DTR step.
Test Data: Attempt `Lunch Out` before `Time In`
Test Steps:
1. Open `Daily Time Record`.
2. Attempt an invalid next action.
Expected Result: The request is rejected and the DTR state remains unchanged.
Actual Result: Pending execution
Test Status: Not Run

### TC-DTR-04
Test Case ID: TC-DTR-04
Test Case Title: Export Student DTR as PDF
Description: Verify that a student can export DTR as PDF.
Precondition: Student has DTR records for the selected period.
Test Data: `GET /api/v1/student/dtr/export/pdf?month=4&year=2026`
Test Steps:
1. Open the DTR export flow.
2. Select PDF export.
3. Export the selected period.
Expected Result: A PDF file is generated and downloaded successfully.
Actual Result: Pending execution
Test Status: Not Run

### TC-DTR-05
Test Case ID: TC-DTR-05
Test Case Title: Export Student DTR as Excel CSV
Description: Verify that a student can export DTR as Excel-compatible CSV.
Precondition: Student has DTR records for the selected period.
Test Data: `GET /api/v1/student/dtr/export/excel?month=4&year=2026`
Test Steps:
1. Open the DTR export flow.
2. Select Excel export.
3. Export the selected period.
Expected Result: A CSV file is generated and downloaded successfully.
Actual Result: Pending execution
Test Status: Not Run

### TC-DTR-06
Test Case ID: TC-DTR-06
Test Case Title: Request DTR Edit
Description: Verify that a student can submit a DTR edit request.
Precondition: Student has an existing DTR entry that needs correction.
Test Data: Valid edit request payload to `POST /api/v1/student/dtr/edit-request`
Test Steps:
1. Open the DTR edit request flow.
2. Enter the requested correction details.
3. Submit the request.
Expected Result: The edit request is created successfully and routed for review.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 6 - LOGBOOK AND ATTACHMENTS

### TC-LOG-01
Test Case ID: TC-LOG-01
Test Case Title: Successful Daily Log Submission
Description: Verify that a student can submit a daily log with valid data.
Precondition: Student has an internship profile.
Test Data: Valid log title, narrative, date, and rendered hours
Test Steps:
1. Open `Logbook`.
2. Create a new log.
3. Enter valid data.
4. Submit the log.
Expected Result: The log is saved successfully and appears in the log list.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-02
Test Case ID: TC-LOG-02
Test Case Title: Future Log Date Rejection
Description: Verify that future log dates are rejected.
Precondition: Student is on log submission screen.
Test Data: Date in the future
Test Steps:
1. Create a new log.
2. Enter a future date.
3. Submit the form.
Expected Result: Validation fails and the log is not saved.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-03
Test Case ID: TC-LOG-03
Test Case Title: View Own Log Details
Description: Verify that a student can view their own log detail.
Precondition: Student has at least one saved log.
Test Data: Existing owned log
Test Steps:
1. Open `Logbook`.
2. Select one of the student's own logs.
Expected Result: The selected log details are displayed.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-04
Test Case ID: TC-LOG-04
Test Case Title: Edit Pending Log Successfully
Description: Verify that a pending log can be edited.
Precondition: Student has a pending log.
Test Data: Valid updated log content
Test Steps:
1. Open a pending log.
2. Edit the log details.
3. Save the changes.
Expected Result: The log is updated successfully.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-05
Test Case ID: TC-LOG-05
Test Case Title: Edit Reviewed Log Is Blocked
Description: Verify that approved or rejected logs cannot be directly edited.
Precondition: Student has an approved or rejected log.
Test Data: Reviewed log
Test Steps:
1. Open a reviewed log.
2. Attempt to edit and save.
Expected Result: Direct editing is blocked.
Actual Result: Pending execution
Test Status: Not Run

### TC-ATT-01
Test Case ID: TC-ATT-01
Test Case Title: Upload Allowed Attachment Types
Description: Verify that a student can upload supported proof attachments to a pending log.
Precondition: Student owns a pending log.
Test Data: Supported image or PDF proof file
Test Steps:
1. Open a pending log.
2. Use the attachment upload control.
3. Select a supported file.
4. Submit the upload.
Expected Result: The attachment is uploaded successfully and appears in the log detail.
Actual Result: Pending execution
Test Status: Not Run

### TC-ATT-02
Test Case ID: TC-ATT-02
Test Case Title: Unsupported Attachment Type Rejection
Description: Verify that unsupported attachment types are rejected.
Precondition: Student owns a pending log.
Test Data: Unsupported file type
Test Steps:
1. Open a pending log.
2. Attempt to upload an unsupported file type.
Expected Result: The upload is rejected and an error is shown.
Actual Result: Pending execution
Test Status: Not Run

### TC-ATT-03
Test Case ID: TC-ATT-03
Test Case Title: Attachment Size Limit Validation
Description: Verify that oversized attachments are rejected.
Precondition: Student owns a pending log.
Test Data: File larger than the allowed size
Test Steps:
1. Open a pending log.
2. Attempt to upload an oversized file.
Expected Result: The upload is rejected and a size validation message is shown.
Actual Result: Pending execution
Test Status: Not Run

### TC-ATT-04
Test Case ID: TC-ATT-04
Test Case Title: Upload Attachment to Reviewed Log Is Blocked
Description: Verify that attachments cannot be added to approved or rejected logs.
Precondition: Student owns an approved or rejected log.
Test Data: Any supported attachment
Test Steps:
1. Open a reviewed log.
2. Attempt to upload an attachment.
Expected Result: The upload is blocked.
Actual Result: Pending execution
Test Status: Not Run

### TC-EDIT-01
Test Case ID: TC-EDIT-01
Test Case Title: Submit Log Edit Request
Description: Verify that a student can submit a log edit request.
Precondition: Student has a log requiring edit review.
Test Data: Valid request to `POST /api/v1/student/logs/{id}/edit-request`
Test Steps:
1. Open the target log.
2. Choose the edit request action.
3. Submit the request with valid reason or updated values.
Expected Result: The edit request is created successfully.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 7 - REPORTS

### TC-REP-01
Test Case ID: TC-REP-01
Test Case Title: Student Report Includes Only Approved Logs
Description: Verify that the student report includes only approved logs and summary data.
Precondition: Student has a mix of approved and non-approved logs.
Test Data: `GET /api/v1/student/report`
Test Steps:
1. Open the student report screen.
2. Load the report data.
Expected Result: Only approved logs appear in the report summary and detail data.
Actual Result: Pending execution
Test Status: Not Run

### TC-REP-02
Test Case ID: TC-REP-02
Test Case Title: Student Report Applies Date Filters
Description: Verify that the student report supports optional date filtering.
Precondition: Student has approved logs across multiple dates.
Test Data: `GET /api/v1/student/report?start_date=2026-03-05&end_date=2026-03-15`
Test Steps:
1. Open the report screen.
2. Apply a start and end date filter.
3. Reload the report.
Expected Result: Only report entries within the selected range are shown.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 8 - SUPERVISOR WORKFLOW

### TC-SUP-01
Test Case ID: TC-SUP-01
Test Case Title: Supervisor Sees Only Assigned Pending Logs
Description: Verify that a supervisor sees only pending logs belonging to assigned interns.
Precondition: Supervisor has assigned interns with pending logs.
Test Data: Supervisor pending queue
Test Steps:
1. Log in as a Supervisor.
2. Open the supervisor dashboard or log queue.
Expected Result: Only assigned pending logs are shown.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-02
Test Case ID: TC-SUP-02
Test Case Title: Supervisor Queue Is Sorted Oldest First
Description: Verify that the supervisor pending review queue is sorted correctly.
Precondition: Supervisor has multiple pending logs.
Test Data: Multiple pending logs with different dates
Test Steps:
1. Open the supervisor queue.
2. Review the order of pending items.
Expected Result: The queue is sorted oldest first.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-03
Test Case ID: TC-SUP-03
Test Case Title: Supervisor Can View Assigned Log Details
Description: Verify that a supervisor can open an assigned intern's log with attachments and history.
Precondition: Assigned intern has a submitted log.
Test Data: Existing assigned log
Test Steps:
1. Open a log from the pending or reviewed queue.
Expected Result: The assigned log detail is displayed correctly.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-04
Test Case ID: TC-SUP-04
Test Case Title: Supervisor Can Approve Pending Log
Description: Verify that a supervisor can approve an assigned pending log.
Precondition: Supervisor owns an assigned pending log in the queue.
Test Data: Pending log ID
Test Steps:
1. Open a pending assigned log.
2. Trigger the approve action.
Expected Result: The log is approved successfully.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-05
Test Case ID: TC-SUP-05
Test Case Title: Supervisor Rejection Requires Comment
Description: Verify that rejecting a log requires a comment.
Precondition: Supervisor owns an assigned pending log.
Test Data: Rejection attempt without comment
Test Steps:
1. Open a pending log.
2. Attempt to reject without entering a comment.
Expected Result: Rejection is blocked until a comment is supplied.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-06
Test Case ID: TC-SUP-06
Test Case Title: Supervisor Cannot View Unassigned Log
Description: Verify that a supervisor cannot access logs outside their assignment scope.
Precondition: Another supervisor owns the target student assignment.
Test Data: Unassigned log ID
Test Steps:
1. Attempt to open an unassigned log directly.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 9 - ADVISER WORKFLOW

### TC-ADV-01
Test Case ID: TC-ADV-01
Test Case Title: Adviser Can View Assigned Intern List
Description: Verify that an adviser can view only assigned interns.
Precondition: Adviser has assigned students.
Test Data: Adviser intern list
Test Steps:
1. Log in as an Adviser.
2. Open the intern list view.
Expected Result: Only assigned interns are shown.
Actual Result: Pending execution
Test Status: Not Run

### TC-ADV-02
Test Case ID: TC-ADV-02
Test Case Title: Adviser Empty State
Description: Verify that the adviser dashboard handles no assigned interns gracefully.
Precondition: Adviser has no assigned interns.
Test Data: Empty adviser assignment state
Test Steps:
1. Log in as an Adviser with no assignments.
2. Open the dashboard or intern list.
Expected Result: An empty state is shown without errors.
Actual Result: Pending execution
Test Status: Not Run

### TC-ADV-03
Test Case ID: TC-ADV-03
Test Case Title: Adviser Cannot View Unassigned Intern Detail
Description: Verify that an adviser cannot access an unassigned intern's details.
Precondition: Target student is not assigned to the adviser.
Test Data: Unassigned student ID
Test Steps:
1. Attempt to open an unassigned intern detail directly.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 10 - ADMIN USER MANAGEMENT AND ASSIGNMENTS

### TC-ADMIN-01
Test Case ID: TC-ADMIN-01
Test Case Title: Admin Can Create User Successfully
Description: Verify that admin can create a user with valid details.
Precondition: Admin is authenticated.
Test Data: Name `Maria Supervisor`; Email `maria.supervisor@example.com`; Role `Supervisor`; Password `Password123`
Test Steps:
1. Open user management.
2. Open `Add User`.
3. Enter valid data.
4. Save the user.
Expected Result: The new user is created and appears in the list.
Actual Result: Pending execution
Test Status: Not Run

### TC-ADMIN-02
Test Case ID: TC-ADMIN-02
Test Case Title: Admin Cannot Create User with Duplicate Email
Description: Verify that admin cannot create a user using an existing email.
Precondition: A user already exists with the target email.
Test Data: Email `maria.supervisor@example.com`
Test Steps:
1. Open `Add User`.
2. Enter a duplicate email.
3. Save.
Expected Result: User creation is rejected and email uniqueness validation is shown.
Actual Result: Pending execution
Test Status: Not Run

### TC-ADMIN-03
Test Case ID: TC-ADMIN-03
Test Case Title: Delete User Successfully
Description: Verify that admin can delete a deletable user account.
Precondition: A deletable user exists.
Test Data: Target user ID
Test Steps:
1. Open user management.
2. Choose a user.
3. Delete and confirm.
Expected Result: The selected user is removed from the list.
Actual Result: Pending execution
Test Status: Not Run

### TC-ADMIN-04
Test Case ID: TC-ADMIN-04
Test Case Title: Assign Adviser to Student Successfully
Description: Verify that admin can assign an adviser to a student.
Precondition: Student and adviser records exist.
Test Data: Student ID; Adviser ID
Test Steps:
1. Open student assignment management.
2. Select a student.
3. Assign an adviser.
4. Save.
Expected Result: Adviser assignment is saved successfully.
Actual Result: Pending execution
Test Status: Not Run

### TC-ADMIN-05
Test Case ID: TC-ADMIN-05
Test Case Title: Assign Supervisor to Student Successfully
Description: Verify that admin can assign a supervisor to a student.
Precondition: Student and supervisor records exist.
Test Data: Student ID; Supervisor ID
Test Steps:
1. Open student assignment management.
2. Select a student.
3. Assign a supervisor.
4. Save.
Expected Result: Supervisor assignment is saved successfully.
Actual Result: Pending execution
Test Status: Not Run

### TC-ADMIN-06
Test Case ID: TC-ADMIN-06
Test Case Title: Non-Admin Access to Admin Dashboard
Description: Verify that non-admin users cannot open admin-only pages or endpoints.
Precondition: Student, Supervisor, or Adviser account is logged in.
Test Data: Admin route or endpoint
Test Steps:
1. Log in as a non-admin role.
2. Attempt to access admin dashboard or admin management pages.
Expected Result: Access is denied or the user is redirected away.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 11 - ROLE-BASED ACCESS CONTROL AND ROUTE GUARDS

### TC-RBAC-01
Test Case ID: TC-RBAC-01
Test Case Title: Student Cannot Access Supervisor Endpoint
Description: Verify that a student account cannot call supervisor-only endpoints.
Precondition: Student is logged in.
Test Data: `GET /api/v1/supervisor/logs`
Test Steps:
1. Authenticate as Student.
2. Attempt to access the supervisor endpoint.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Status: Not Run

### TC-RBAC-02
Test Case ID: TC-RBAC-02
Test Case Title: Student Cannot Access Admin Endpoint
Description: Verify that a student account cannot call admin-only endpoints.
Precondition: Student is logged in.
Test Data: `GET /api/v1/admin/dashboard`
Test Steps:
1. Authenticate as Student.
2. Attempt to open the admin dashboard endpoint.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Status: Not Run

### TC-RBAC-03
Test Case ID: TC-RBAC-03
Test Case Title: Adviser Cannot Create Student Log
Description: Verify that an adviser cannot use student-only log submission endpoints.
Precondition: Adviser is logged in.
Test Data: `POST /api/v1/student/logs`
Test Steps:
1. Authenticate as Adviser.
2. Submit a student log payload.
Expected Result: Access is denied and no log is created.
Actual Result: Pending execution
Test Status: Not Run

### TC-RBAC-04
Test Case ID: TC-RBAC-04
Test Case Title: Role Route Guard Redirects Wrong Role
Description: Verify that the Flutter role guard redirects users who open another role's route.
Precondition: User is logged in under any role.
Test Data: Student opens supervisor or admin dashboard route
Test Steps:
1. Log in as Student.
2. Navigate directly to a supervisor or admin route.
Expected Result: The app redirects the user back to the correct dashboard for their role.
Actual Result: Pending execution
Test Status: Not Run

### TC-RBAC-05
Test Case ID: TC-RBAC-05
Test Case Title: Guest Cannot Access Protected Route
Description: Verify that unauthenticated users cannot open protected screens.
Precondition: User is logged out.
Test Data: Protected route such as `/settings`
Test Steps:
1. Open a protected route directly while logged out.
Expected Result: The login screen is shown instead of the protected screen.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 12 - API FOUNDATION, SECURITY, AND SYSTEM RESILIENCE

### TC-SEC-01
Test Case ID: TC-SEC-01
Test Case Title: Public Health Endpoint Responds Successfully
Description: Verify that the public health endpoint is accessible without login.
Precondition: API server is running.
Test Data: `GET /api/v1/health`
Test Steps:
1. Send a request to the health endpoint without authentication.
Expected Result: The endpoint responds successfully with API status information.
Actual Result: Pending execution
Test Status: Not Run

### TC-SEC-02
Test Case ID: TC-SEC-02
Test Case Title: Protected Endpoint Without Token
Description: Verify that protected endpoints reject unauthenticated requests.
Precondition: No valid token is attached to the request.
Test Data: `GET /api/v1/notifications`
Test Steps:
1. Call a protected endpoint without a token.
Expected Result: The request is rejected as unauthenticated.
Actual Result: Pending execution
Test Status: Not Run

### TC-SEC-03
Test Case ID: TC-SEC-03
Test Case Title: Protected Endpoint with Invalid Token
Description: Verify that requests using an invalid token are rejected.
Precondition: An invalid or expired token is available.
Test Data: Invalid bearer token
Test Steps:
1. Call a protected endpoint using the invalid token.
Expected Result: Access is denied and the user is treated as unauthenticated.
Actual Result: Pending execution
Test Status: Not Run

### TC-SEC-04
Test Case ID: TC-SEC-04
Test Case Title: Input Sanitization on Text Field
Description: Verify that unsafe script-like input is sanitized or rejected.
Precondition: User can submit a text field such as a log narrative or profile value.
Test Data: `<script>alert('x')</script>`
Test Steps:
1. Enter the payload into a supported text field.
2. Submit the form.
3. Reload the saved data if accepted.
Expected Result: Unsafe script content is sanitized or rejected and never rendered as executable code.
Actual Result: Pending execution
Test Status: Not Run

### TC-SEC-05
Test Case ID: TC-SEC-05
Test Case Title: Rate Limit on Login Attempts
Description: Verify that repeated login attempts are throttled when limits are exceeded.
Precondition: Login endpoint is available.
Test Data: More than the allowed number of rapid invalid login attempts
Test Steps:
1. Repeatedly submit invalid login credentials.
2. Continue until the threshold is exceeded.
Expected Result: The system throttles requests and returns a limit message.
Actual Result: Pending execution
Test Status: Not Run

### TC-SEC-06
Test Case ID: TC-SEC-06
Test Case Title: Rate Limit on Attachment Upload
Description: Verify that repeated attachment uploads are throttled when limits are exceeded.
Precondition: Student owns a log eligible for uploads.
Test Data: More than the allowed number of upload attempts in a short time
Test Steps:
1. Repeatedly trigger attachment upload requests.
2. Continue beyond the allowed limit.
Expected Result: The endpoint applies throttling and returns a limit response.
Actual Result: Pending execution
Test Status: Not Run

### TC-SEC-07
Test Case ID: TC-SEC-07
Test Case Title: API Handles Not Found Record Gracefully
Description: Verify that requests for nonexistent records return safe not-found responses.
Precondition: User is authenticated.
Test Data: Nonexistent log ID or user ID
Test Steps:
1. Request a record using an invalid ID that does not exist.
Expected Result: The API returns a safe not-found response without exposing internal details.
Actual Result: Pending execution
Test Status: Not Run

### TC-SEC-08
Test Case ID: TC-SEC-08
Test Case Title: API Response on Forced Server Error Path
Description: Verify that the system returns controlled error behavior when an internal failure occurs.
Precondition: A safe non-production failure simulation setup is available.
Test Data: Controlled server-side failure scenario
Test Steps:
1. Trigger a controlled server-side failure scenario.
2. Observe the client and API behavior.
Expected Result: The system returns a controlled error response and does not expose sensitive stack information to the user.
Actual Result: Pending execution
Test Status: Not Run
