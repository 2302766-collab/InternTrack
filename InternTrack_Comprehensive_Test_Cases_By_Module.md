# INTERNTRACK
## Comprehensive Manual Test Cases by Module

Document purpose:
- Provide a fuller manual test case set for the current InternTrack system.
- Organize coverage by module and role.
- Use the required fields: `Test Case ID`, `Test Case Title`, `Description`, `Precondition`, `Test Data`, `Test Step`, `Expected Result`, `Actual Result`, and `Test Result`.

Execution note:
- `Actual Result`: `Pending execution`
- `Test Result`: `Not Run`
- Update those two fields during actual testing.

---

## MODULE 1 - AUTHENTICATION AND SESSION

### TC-AUTH-01
Test Case ID: TC-AUTH-01
Test Case Title: Successful Student Registration
Description: Verify that a new student can create an account using valid registration data.
Precondition: The email address is not yet registered in the system.
Test Data: Name `Juan Dela Cruz`; Email `juan@example.com`; Password `Password123`; Confirm Password `Password123`
Test Step:
1. Open the app.
2. Navigate to `Create Account`.
3. Enter valid name, email, password, and confirmation.
4. Tap `Register`.
Expected Result: Registration succeeds and the user is redirected to the login screen with a success message.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-02
Test Case ID: TC-AUTH-02
Test Case Title: Duplicate Email Registration
Description: Verify that the system blocks registration when the email already exists.
Precondition: An account already uses the test email.
Test Data: Name `Juan Dela Cruz`; Email `juan@example.com`; Password `Password123`
Test Step:
1. Open the registration screen.
2. Enter valid details using an existing email.
3. Submit the form.
Expected Result: Registration is rejected and an email-already-registered validation message is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-03
Test Case ID: TC-AUTH-03
Test Case Title: Invalid Email Format During Registration
Description: Verify that registration requires a properly formatted email address.
Precondition: User is on the registration screen.
Test Data: Email `juanexample.com`
Test Step:
1. Enter a valid full name.
2. Enter an invalid email format.
3. Enter valid password and confirmation values.
4. Tap `Register`.
Expected Result: The form does not submit and the email field shows a validation error.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-04
Test Case ID: TC-AUTH-04
Test Case Title: Password Confirmation Mismatch
Description: Verify that registration is blocked when the password and confirmation do not match.
Precondition: User is on the registration screen.
Test Data: Password `Password123`; Confirm Password `Password124`
Test Step:
1. Fill in valid name and email values.
2. Enter different password and confirm password values.
3. Submit the form.
Expected Result: Registration is blocked and a password mismatch validation message is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-05
Test Case ID: TC-AUTH-05
Test Case Title: Successful Login by Valid User
Description: Verify that a registered user can log in successfully using correct credentials.
Precondition: A valid user account exists.
Test Data: Email `student@example.com`; Password `Password123`
Test Step:
1. Open the login screen.
2. Enter valid credentials.
3. Tap `Login`.
Expected Result: Login succeeds, the token is stored, and the user is redirected to the correct dashboard.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-06
Test Case ID: TC-AUTH-06
Test Case Title: Login with Invalid Password
Description: Verify that the system rejects login when the password is incorrect.
Precondition: A valid user account exists.
Test Data: Email `student@example.com`; Password `WrongPass123`
Test Step:
1. Open the login screen.
2. Enter a valid email and invalid password.
3. Tap `Login`.
Expected Result: Login fails and the UI displays an invalid credentials message.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-07
Test Case ID: TC-AUTH-07
Test Case Title: Role-Based Redirect After Login
Description: Verify that student, supervisor, adviser, and admin users land on their own dashboard after login.
Precondition: Valid accounts exist for all supported roles.
Test Data: Student, Supervisor, Adviser, and Admin credentials
Test Step:
1. Log in as a Student account.
2. Observe the landing page.
3. Repeat for Supervisor, Adviser, and Admin accounts.
Expected Result: Each role is redirected to its corresponding dashboard.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-08
Test Case ID: TC-AUTH-08
Test Case Title: Auth Gate Restores Active Session
Description: Verify that the app restores an existing authenticated session on relaunch.
Precondition: A valid token is already stored on the device.
Test Data: Stored token for each role
Test Step:
1. Log in successfully.
2. Close the app completely.
3. Reopen the app.
Expected Result: The app bypasses guest screens and opens the proper protected dashboard.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-09
Test Case ID: TC-AUTH-09
Test Case Title: Logout Clears Session
Description: Verify that logout removes the authenticated session.
Precondition: User is logged in.
Test Data: Any valid active session
Test Step:
1. Open the app while logged in.
2. Tap the logout action.
3. Reopen the app or revisit a protected route.
Expected Result: The session is cleared and the user is returned to the login screen.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-10
Test Case ID: TC-AUTH-10
Test Case Title: Guest Route Guard Blocks Login Screen for Authenticated User
Description: Verify that an authenticated user cannot stay on guest-only routes like login or registration.
Precondition: User is already authenticated.
Test Data: Valid stored session
Test Step:
1. Log in to the system.
2. Attempt to open the `Login` or `Register` route directly.
Expected Result: The app redirects the user back to the correct dashboard.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 2 - ACCOUNT PROFILE AND SETTINGS

### TC-ACC-01
Test Case ID: TC-ACC-01
Test Case Title: View Current User Profile
Description: Verify that an authenticated user can retrieve their own account profile.
Precondition: User is logged in.
Test Data: Any valid authenticated account
Test Step:
1. Log in to the app.
2. Open the settings or profile area.
3. Load current user information.
Expected Result: The app displays the correct logged-in user details.
Actual Result: Pending execution
Test Result: Not Run

### TC-ACC-02
Test Case ID: TC-ACC-02
Test Case Title: Update User Profile Information
Description: Verify that an authenticated user can update editable profile information.
Precondition: User is logged in.
Test Data: Updated name `Juan Updated`; Updated gender `Male`
Test Step:
1. Open profile settings.
2. Change editable profile fields.
3. Save the changes.
4. Reload the profile view.
Expected Result: Updated profile data is saved and shown correctly after refresh.
Actual Result: Pending execution
Test Result: Not Run

### TC-ACC-03
Test Case ID: TC-ACC-03
Test Case Title: Upload Avatar Image
Description: Verify that a user can upload a valid avatar image.
Precondition: User is logged in and has access to an image file.
Test Data: Valid image file `avatar.jpg`
Test Step:
1. Open the profile settings area.
2. Choose an avatar image.
3. Save the upload.
Expected Result: The avatar is uploaded successfully and displayed in the UI.
Actual Result: Pending execution
Test Result: Not Run

### TC-ACC-04
Test Case ID: TC-ACC-04
Test Case Title: Reject Invalid Avatar Upload
Description: Verify that unsupported or invalid avatar uploads are rejected.
Precondition: User is logged in.
Test Data: Unsupported file `avatar.txt`
Test Step:
1. Open avatar update.
2. Select an unsupported file type.
3. Submit the upload.
Expected Result: The upload is rejected and an error message is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-ACC-05
Test Case ID: TC-ACC-05
Test Case Title: Theme Preference Persists
Description: Verify that theme changes made in settings persist across app restarts.
Precondition: User is logged in and settings screen is accessible.
Test Data: Theme mode `Dark` or `Light`
Test Step:
1. Open settings.
2. Change the theme mode.
3. Close and reopen the app.
Expected Result: The selected theme remains applied after relaunch.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 3 - NOTIFICATIONS

### TC-NOTIF-01
Test Case ID: TC-NOTIF-01
Test Case Title: View Notification List
Description: Verify that a logged-in user can view their notifications.
Precondition: The user has at least one notification.
Test Data: Read and unread notification records
Test Step:
1. Log in to the app.
2. Open the notifications list.
Expected Result: The user sees only their own notifications ordered by most recent first.
Actual Result: Pending execution
Test Result: Not Run

### TC-NOTIF-02
Test Case ID: TC-NOTIF-02
Test Case Title: Mark Notification as Read
Description: Verify that a user can mark their own unread notification as read.
Precondition: The user has at least one unread notification.
Test Data: Valid owned notification ID
Test Step:
1. Open the notification list.
2. Tap or trigger `Mark as Read` on an unread item.
3. Refresh the list if needed.
Expected Result: The notification state changes to read and the unread count decreases.
Actual Result: Pending execution
Test Result: Not Run

### TC-NOTIF-03
Test Case ID: TC-NOTIF-03
Test Case Title: Notification Detail Redirect for Student Log Alert
Description: Verify that a student notification tied to a log routes the user to the correct target screen.
Precondition: Student is logged in and receives a notification referencing a log entry.
Test Data: Notification linked to a student log ID
Test Step:
1. Open the notification list.
2. Tap the log-related notification.
Expected Result: The app opens the relevant logbook or log detail context for the referenced log.
Actual Result: Pending execution
Test Result: Not Run

### TC-NOTIF-04
Test Case ID: TC-NOTIF-04
Test Case Title: Prevent Cross-User Notification Update
Description: Verify that a user cannot update another user's notification state.
Precondition: Two users exist and the target notification belongs to another account.
Test Data: Notification ID owned by a different user
Test Step:
1. Authenticate as User B.
2. Attempt to mark User A's notification as read through the API or app flow.
Expected Result: The action is denied and the target notification remains unchanged.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 4 - INTERNSHIP PROFILE MANAGEMENT

### TC-PROF-01
Test Case ID: TC-PROF-01
Test Case Title: Load Supervisor Options
Description: Verify that a student can retrieve the list of valid supervisors before creating a profile.
Precondition: At least one supervisor account exists.
Test Data: None
Test Step:
1. Log in as a student.
2. Open the internship profile screen.
3. Load the supervisor selection list.
Expected Result: Only valid supervisor accounts are shown as selectable options.
Actual Result: Pending execution
Test Result: Not Run

### TC-PROF-02
Test Case ID: TC-PROF-02
Test Case Title: Create Internship Profile with Valid Data
Description: Verify that a student can create an internship profile successfully.
Precondition: Student account has no existing internship profile.
Test Data: Company `Acme Corp`; Address `Tacloban City`; Required Hours `486`; Start `2026-06-01`; End `2026-09-30`; Supervisor ID valid
Test Step:
1. Open internship profile.
2. Enter complete valid internship information.
3. Submit the form.
Expected Result: The internship profile is created and shown in the UI.
Actual Result: Pending execution
Test Result: Not Run

### TC-PROF-03
Test Case ID: TC-PROF-03
Test Case Title: Update Internship Profile
Description: Verify that a student can update an existing internship profile.
Precondition: Student already has an internship profile.
Test Data: Updated company `Acme Revised Corp`; Required Hours `600`
Test Step:
1. Open the existing internship profile.
2. Edit one or more fields.
3. Save the changes.
4. Reload the screen.
Expected Result: The updated internship profile values persist after refresh.
Actual Result: Pending execution
Test Result: Not Run

### TC-PROF-04
Test Case ID: TC-PROF-04
Test Case Title: Reject Non-Supervisor Assignment in Internship Profile
Description: Verify that a student cannot assign a non-supervisor user as supervisor.
Precondition: A non-supervisor account exists.
Test Data: Internship payload using a Student or Adviser ID as supervisor
Test Step:
1. Open internship profile creation or update.
2. Submit data using an invalid supervisor ID.
Expected Result: The request fails validation and the profile is not saved.
Actual Result: Pending execution
Test Result: Not Run

### TC-PROF-05
Test Case ID: TC-PROF-05
Test Case Title: Required Internship Fields Validation
Description: Verify that required internship profile fields cannot be left blank.
Precondition: Student is on the internship profile form.
Test Data: Blank company name or blank start date
Test Step:
1. Open the internship profile form.
2. Leave one required field blank.
3. Attempt to save.
Expected Result: Validation messages are displayed and the profile is not submitted.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 5 - DAILY TIME RECORD

### TC-DTR-01
Test Case ID: TC-DTR-01
Test Case Title: View Today's DTR Initial State
Description: Verify that a student sees the correct starting DTR state when no record exists for the day.
Precondition: No DTR exists for the student for the current day.
Test Data: None
Test Step:
1. Log in as a student.
2. Open the DTR screen.
Expected Result: The screen shows `Not Started` and the next available action is `Time In`.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-02
Test Case ID: TC-DTR-02
Test Case Title: Successful Time In
Description: Verify that a student can record a valid time-in action.
Precondition: No DTR exists yet for the current day.
Test Data: Current date and system time
Test Step:
1. Open the DTR screen.
2. Tap `Time In`.
Expected Result: The time-in action is saved and the DTR state changes to working.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-03
Test Case ID: TC-DTR-03
Test Case Title: Successful Lunch Out and Lunch In Sequence
Description: Verify that lunch break transitions work in the correct order.
Precondition: Student has already completed `Time In`.
Test Data: Current date and time
Test Step:
1. Tap `Lunch Out`.
2. Confirm the state changes.
3. Tap `Lunch In`.
Expected Result: The DTR state changes to `On Break` after lunch out and returns to `Working` after lunch in.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-04
Test Case ID: TC-DTR-04
Test Case Title: Successful Time Out Completion
Description: Verify that a student can complete the DTR cycle with a valid time-out action.
Precondition: Student has already completed `Time In` and is currently in a valid state to time out.
Test Data: Current date and time
Test Step:
1. Tap `Time Out`.
2. Refresh the DTR view.
Expected Result: The day record becomes completed and total rendered work time is updated.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-05
Test Case ID: TC-DTR-05
Test Case Title: Reject Lunch Out Before Time In
Description: Verify that invalid DTR action order is blocked.
Precondition: No `Time In` exists for the day.
Test Data: Attempt action `Lunch Out`
Test Step:
1. Try to execute `Lunch Out` before `Time In`.
Expected Result: The action is rejected and an explanatory validation or conflict message is returned.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-06
Test Case ID: TC-DTR-06
Test Case Title: Reject Time Out Before Required Prior Steps
Description: Verify that a student cannot time out before entering a valid working state.
Precondition: The DTR sequence is incomplete or invalid.
Test Data: Attempt action `Time Out` before `Time In` or before `Lunch In` after a break
Test Step:
1. Attempt a premature `Time Out`.
Expected Result: The request is rejected and the DTR record remains unchanged.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-07
Test Case ID: TC-DTR-07
Test Case Title: View Monthly DTR Summary
Description: Verify that a student can retrieve monthly DTR data.
Precondition: DTR records exist within the target month.
Test Data: Current month with at least one completed record
Test Step:
1. Open the monthly DTR summary view.
2. Select or load the current month.
Expected Result: The system displays the correct monthly DTR entries and totals.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-08
Test Case ID: TC-DTR-08
Test Case Title: Student Export DTR to PDF
Description: Verify that a student can export their own DTR to PDF.
Precondition: DTR entries exist for the target period.
Test Data: Valid month with completed records
Test Step:
1. Open the DTR screen.
2. Choose `Export PDF`.
Expected Result: A PDF file is generated or downloaded successfully for the student.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 6 - STUDENT LOGBOOK AND ATTACHMENTS

### TC-LOG-01
Test Case ID: TC-LOG-01
Test Case Title: View Student Log List
Description: Verify that a student can view their own logbook entries.
Precondition: Student has at least one existing log entry.
Test Data: Student-owned logs across different dates
Test Step:
1. Log in as a student.
2. Open the logbook screen.
Expected Result: Only the student's own logs are displayed with their correct details.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-02
Test Case ID: TC-LOG-02
Test Case Title: Submit New Log Entry
Description: Verify that a student can create a valid log entry.
Precondition: Student has an internship profile and access to the log submission screen.
Test Data: Date `2026-05-20`; Time In `08:00`; Time Out `17:00`; Hours `8`; Narrative `Performed QA testing tasks`
Test Step:
1. Open the log submission screen.
2. Enter valid log information.
3. Submit the log.
Expected Result: The log is saved successfully and appears in the logbook list.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-03
Test Case ID: TC-LOG-03
Test Case Title: View Log Detail
Description: Verify that a student can open a specific log entry and view its details.
Precondition: Student has at least one saved log.
Test Data: Existing log ID
Test Step:
1. Open the logbook list.
2. Select a log entry.
Expected Result: The system displays the selected log's complete details.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-04
Test Case ID: TC-LOG-04
Test Case Title: Edit Pending Log Entry
Description: Verify that a student can update a pending log entry.
Precondition: Student owns a log whose status allows editing.
Test Data: Updated narrative `Performed documentation and testing tasks`
Test Step:
1. Open a pending log entry.
2. Choose the edit action.
3. Update one or more fields.
4. Save the changes.
Expected Result: The log updates successfully and the new values appear in the detail view.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-05
Test Case ID: TC-LOG-05
Test Case Title: Validate Required Log Fields
Description: Verify that required log fields must be completed before submission.
Precondition: Student is on the log submission form.
Test Data: Blank narrative or missing time values
Test Step:
1. Leave one required field blank.
2. Try to submit the log.
Expected Result: The form blocks submission and shows validation messages.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-06
Test Case ID: TC-LOG-06
Test Case Title: Upload Valid Attachment to Log
Description: Verify that a student can upload a supported proof attachment to a log.
Precondition: Student owns a log that allows proof upload.
Test Data: File `proof.jpg` or `proof.pdf`
Test Step:
1. Open the log detail screen.
2. Choose `Upload Attachment`.
3. Select a supported file.
4. Submit the upload.
Expected Result: The attachment uploads successfully and is associated with the log.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-07
Test Case ID: TC-LOG-07
Test Case Title: Reject Unsupported Attachment Type
Description: Verify that unsupported log attachment file types are rejected.
Precondition: Student owns a log that allows proof upload.
Test Data: File `proof.exe`
Test Step:
1. Open a log entry.
2. Attempt to upload an unsupported file.
Expected Result: The upload is rejected and an appropriate error is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-08
Test Case ID: TC-LOG-08
Test Case Title: Prevent Duplicate Proof Attachment
Description: Verify that the system does not allow adding a second proof file when one already exists.
Precondition: Student log already has one uploaded proof attachment.
Test Data: Another valid image or PDF file
Test Step:
1. Open a log with an existing attachment.
2. Attempt a second proof upload.
Expected Result: The second upload is blocked and the original attachment remains intact.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-09
Test Case ID: TC-LOG-09
Test Case Title: Download Student-Owned Log Attachment
Description: Verify that a student can download an attachment belonging to their own log.
Precondition: Student owns a log with an uploaded attachment.
Test Data: Existing owned attachment ID
Test Step:
1. Open the log detail view.
2. Tap the attachment download action.
Expected Result: The attachment is downloaded or opened successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-10
Test Case ID: TC-LOG-10
Test Case Title: Prevent Access to Another Student's Log
Description: Verify that a student cannot view another student's log entry.
Precondition: Two student accounts exist with separate log entries.
Test Data: Log ID owned by another student
Test Step:
1. Log in as Student B.
2. Attempt to open Student A's log directly through API or deep link flow.
Expected Result: Access is denied and no other student's log data is exposed.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 7 - EDIT REQUEST WORKFLOW

### TC-EDIT-01
Test Case ID: TC-EDIT-01
Test Case Title: Submit Log Edit Request
Description: Verify that a student can request an edit for an existing log entry.
Precondition: Student owns a log eligible for edit request submission.
Test Data: Reason `Need to correct logged hours`
Test Step:
1. Open the target log.
2. Choose `Request Edit`.
3. Enter the request reason.
4. Submit.
Expected Result: The edit request is saved and a confirmation message is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-02
Test Case ID: TC-EDIT-02
Test Case Title: Submit DTR Edit Request
Description: Verify that a student can request an edit for DTR data.
Precondition: Student has an existing DTR record to be corrected.
Test Data: Reason `Forgot to time out on 2026-05-20`
Test Step:
1. Open DTR-related correction or request flow.
2. Enter the needed correction reason.
3. Submit the edit request.
Expected Result: The DTR edit request is recorded successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-03
Test Case ID: TC-EDIT-03
Test Case Title: View Pending Edit Requests in Admin Module
Description: Verify that admin users can view submitted edit requests.
Precondition: At least one edit request exists in the system.
Test Data: Submitted log or DTR edit request
Test Step:
1. Log in as an admin.
2. Open the edit request management area.
Expected Result: The pending edit request list is displayed with relevant request details.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-04
Test Case ID: TC-EDIT-04
Test Case Title: Approve Edit Request
Description: Verify that an admin can approve a submitted edit request.
Precondition: A pending edit request exists.
Test Data: Pending edit request ID
Test Step:
1. Open the edit request list as admin.
2. Select a pending request.
3. Approve the request.
Expected Result: The request status changes to approved and related follow-up behavior is triggered.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-05
Test Case ID: TC-EDIT-05
Test Case Title: Reject Edit Request
Description: Verify that an admin can reject a submitted edit request.
Precondition: A pending edit request exists.
Test Data: Pending edit request ID; Rejection note if supported
Test Step:
1. Open the edit request list as admin.
2. Select a pending request.
3. Reject the request.
Expected Result: The request status changes to rejected and the decision is reflected in the system.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 8 - REPORTS AND EXPORTS

### TC-REP-01
Test Case ID: TC-REP-01
Test Case Title: View Student Progress Report
Description: Verify that a student can view their own internship progress report.
Precondition: Student has internship profile and related DTR or log data.
Test Data: Student with active internship records
Test Step:
1. Log in as a student.
2. Open the report screen.
Expected Result: The report loads successfully and shows the student's own progress metrics.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-02
Test Case ID: TC-REP-02
Test Case Title: Supervisor View of Assigned Student Report
Description: Verify that a supervisor can view the report of an assigned student.
Precondition: Supervisor is assigned to at least one student.
Test Data: Assigned student ID
Test Step:
1. Log in as a supervisor.
2. Open the assigned intern list.
3. Select a student and open the report.
Expected Result: The supervisor sees the report data for the selected assigned student.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-03
Test Case ID: TC-REP-03
Test Case Title: Adviser View of Assigned Student Report
Description: Verify that an adviser can view the report of a student assigned to them.
Precondition: Adviser has at least one assigned student.
Test Data: Assigned student ID
Test Step:
1. Log in as an adviser.
2. Open the intern list.
3. Select an assigned student.
4. Open the report.
Expected Result: The adviser sees the correct report data for the chosen student.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-04
Test Case ID: TC-REP-04
Test Case Title: Supervisor Export Student DTR to PDF
Description: Verify that a supervisor can export the DTR of an assigned student.
Precondition: Supervisor is assigned to the target student and DTR data exists.
Test Data: Assigned student ID; target month
Test Step:
1. Open the selected student's detail or report view.
2. Choose `Export DTR PDF`.
Expected Result: A PDF export is generated successfully for the selected assigned student.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-05
Test Case ID: TC-REP-05
Test Case Title: Adviser Export Student DTR to Excel
Description: Verify that an adviser can export the DTR of an assigned student to Excel.
Precondition: Adviser is assigned to the target student and DTR data exists.
Test Data: Assigned student ID; target month
Test Step:
1. Open the chosen student's record.
2. Choose `Export DTR Excel`.
Expected Result: An Excel export is generated successfully for the selected assigned student.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 9 - SUPERVISOR DASHBOARD AND INTERN MONITORING

### TC-SUPD-01
Test Case ID: TC-SUPD-01
Test Case Title: View Supervisor Dashboard Summary
Description: Verify that a supervisor can view dashboard summary data for assigned interns and pending items.
Precondition: Supervisor account is logged in.
Test Data: Supervisor with assigned interns and at least one pending log
Test Step:
1. Log in as a supervisor.
2. Open the supervisor dashboard.
Expected Result: The dashboard loads summary metrics relevant to the supervisor's assigned interns.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-02
Test Case ID: TC-SUPD-02
Test Case Title: View Assigned Intern List
Description: Verify that a supervisor can view only students assigned to them.
Precondition: Supervisor has one or more assigned interns.
Test Data: Assigned and unassigned student records
Test Step:
1. Open the intern list as supervisor.
2. Review the returned students.
Expected Result: Only the supervisor's assigned interns are listed.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-03
Test Case ID: TC-SUPD-03
Test Case Title: Open Intern Detail Page
Description: Verify that a supervisor can view detailed information for an assigned intern.
Precondition: Supervisor has at least one assigned student.
Test Data: Assigned student ID
Test Step:
1. Open the supervisor intern list.
2. Select one assigned student.
Expected Result: The intern detail page loads with correct profile, progress, and related data.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-04
Test Case ID: TC-SUPD-04
Test Case Title: View Intern Progress Data
Description: Verify that a supervisor can view progress information for an assigned intern.
Precondition: Assigned student has reportable progress records.
Test Data: Assigned student ID with completed logs or DTR entries
Test Step:
1. Open the intern detail page.
2. Load the progress section.
Expected Result: The progress information is displayed accurately for the selected student.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-05
Test Case ID: TC-SUPD-05
Test Case Title: Prevent Supervisor Access to Unassigned Intern Detail
Description: Verify that a supervisor cannot access a student who is not assigned to them.
Precondition: Another student exists outside the supervisor's assignment set.
Test Data: Unassigned student ID
Test Step:
1. Log in as a supervisor.
2. Attempt to open an unassigned student's detail record.
Expected Result: Access is denied and the other student's data is not shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-06
Test Case ID: TC-SUPD-06
Test Case Title: Supervisor Pagination or Load More for Intern List
Description: Verify that intern listing remains usable when the supervisor has many assigned students.
Precondition: Supervisor has enough assigned students to trigger pagination or scrolling behavior.
Test Data: More than one page of assigned students
Test Step:
1. Open the intern list.
2. Navigate through list pagination or load additional entries.
Expected Result: Additional intern records load correctly without duplication or missing entries.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 10 - SUPERVISOR LOG REVIEW

### TC-SUPL-01
Test Case ID: TC-SUPL-01
Test Case Title: View Pending Log Queue
Description: Verify that a supervisor can see logs pending their review.
Precondition: At least one assigned student has a pending log.
Test Data: Pending log items for assigned students
Test Step:
1. Log in as a supervisor.
2. Open the log review queue.
Expected Result: The queue shows reviewable logs for assigned students only.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-02
Test Case ID: TC-SUPL-02
Test Case Title: Open Log Review Detail
Description: Verify that a supervisor can open a pending log and inspect its full content.
Precondition: A pending assigned-student log exists.
Test Data: Pending log ID
Test Step:
1. Select a log from the queue.
2. Open the detail page.
Expected Result: The selected log details, timestamps, and attachments are shown correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-03
Test Case ID: TC-SUPL-03
Test Case Title: Approve Pending Log
Description: Verify that a supervisor can approve a student's pending log entry.
Precondition: Pending log exists for an assigned student.
Test Data: Pending log ID
Test Step:
1. Open the log detail page.
2. Tap `Approve`.
3. Confirm the action if prompted.
Expected Result: The log status changes to approved and the student receives the corresponding update.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-04
Test Case ID: TC-SUPL-04
Test Case Title: Reject Pending Log
Description: Verify that a supervisor can reject a student's pending log entry.
Precondition: Pending log exists for an assigned student.
Test Data: Pending log ID; Rejection reason if supported
Test Step:
1. Open the log detail page.
2. Tap `Reject`.
3. Provide a reason if required.
4. Confirm the action.
Expected Result: The log status changes to rejected and the student receives the corresponding update.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-05
Test Case ID: TC-SUPL-05
Test Case Title: Download Log Attachment During Review
Description: Verify that a supervisor can open or download the proof attachment of an assigned student's log.
Precondition: The pending or reviewed log contains an attachment.
Test Data: Valid attachment ID under an assigned student's log
Test Step:
1. Open the log detail page.
2. Trigger attachment download.
Expected Result: The attachment downloads or opens successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-06
Test Case ID: TC-SUPL-06
Test Case Title: Prevent Re-Review of Already Finalized Log
Description: Verify that a finalized log cannot be processed again improperly.
Precondition: The target log has already been approved or rejected.
Test Data: Finalized log ID
Test Step:
1. Open or submit another approval or rejection action for the finalized log.
Expected Result: The system blocks the invalid repeat review action and preserves the finalized state.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 11 - ADVISER MONITORING

### TC-ADV-01
Test Case ID: TC-ADV-01
Test Case Title: View Adviser Intern List
Description: Verify that an adviser can view students assigned to them.
Precondition: Adviser has at least one assigned student.
Test Data: Adviser with assigned interns
Test Step:
1. Log in as an adviser.
2. Open the intern listing view.
Expected Result: Only students assigned to the adviser are listed.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-02
Test Case ID: TC-ADV-02
Test Case Title: Open Adviser Intern Detail
Description: Verify that an adviser can inspect detailed information for an assigned intern.
Precondition: Adviser has at least one assigned intern.
Test Data: Assigned student ID
Test Step:
1. Open the adviser intern list.
2. Select an assigned student.
Expected Result: The chosen student's detail data loads correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-03
Test Case ID: TC-ADV-03
Test Case Title: View Student Log as Adviser
Description: Verify that an adviser can open a log entry tied to an assigned student.
Precondition: Assigned student has at least one log record.
Test Data: Log ID belonging to an assigned student
Test Step:
1. Open the assigned student's details.
2. Open one of the student's logs.
Expected Result: The adviser can view the log content without modification controls outside their role.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-04
Test Case ID: TC-ADV-04
Test Case Title: Download Assigned Student Attachment as Adviser
Description: Verify that an adviser can access proof attachments related to an assigned student's log.
Precondition: Assigned student's log contains an attachment.
Test Data: Log attachment ID for an assigned student
Test Step:
1. Open the student's log detail as adviser.
2. Download the attachment.
Expected Result: The attachment is downloaded or opened successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-05
Test Case ID: TC-ADV-05
Test Case Title: Prevent Adviser Access to Unassigned Student
Description: Verify that an adviser cannot view students outside their own assignment list.
Precondition: Another student exists who is assigned to a different adviser or none.
Test Data: Unassigned student ID
Test Step:
1. Log in as an adviser.
2. Attempt to open the unassigned student's detail or report.
Expected Result: Access is denied and no unauthorized student information is shown.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 12 - ADMIN DASHBOARD, USER MANAGEMENT, AND ASSIGNMENTS

### TC-ADMIN-01
Test Case ID: TC-ADMIN-01
Test Case Title: View Admin Dashboard Metrics
Description: Verify that an admin can access overall dashboard metrics.
Precondition: Admin account exists and is logged in.
Test Data: Existing records for users, students, logs, or pending items
Test Step:
1. Log in as admin.
2. Open the admin dashboard.
Expected Result: The dashboard loads and displays summary metrics correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-02
Test Case ID: TC-ADMIN-02
Test Case Title: View Student List
Description: Verify that an admin can retrieve the full student list.
Precondition: Multiple student records exist.
Test Data: Existing students across different statuses
Test Step:
1. Open the admin student management area.
2. Load the student list.
Expected Result: The student list loads successfully with relevant student information.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-03
Test Case ID: TC-ADMIN-03
Test Case Title: View User Management List
Description: Verify that an admin can view the user management listing.
Precondition: Users exist for at least two roles.
Test Data: Student, Supervisor, Adviser, and Admin user records
Test Step:
1. Open the user management view.
2. Load users.
Expected Result: The user list displays existing accounts with their correct roles.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-04
Test Case ID: TC-ADMIN-04
Test Case Title: Create New User Account
Description: Verify that an admin can create a new user account.
Precondition: Admin is logged in and the target email is unused.
Test Data: Name `Maria Admin`; Email `maria.supervisor@example.com`; Role `Supervisor`; Password `Password123`
Test Step:
1. Open user management.
2. Choose `Add User`.
3. Enter valid account details.
4. Save.
Expected Result: The new user account is created successfully and appears in the user list.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-05
Test Case ID: TC-ADMIN-05
Test Case Title: Prevent Duplicate User Creation
Description: Verify that the admin cannot create a user using an existing email address.
Precondition: A user already exists with the target email.
Test Data: Existing email `maria.supervisor@example.com`
Test Step:
1. Open `Add User`.
2. Enter the duplicate email.
3. Save.
Expected Result: User creation is rejected and an email uniqueness validation message is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-06
Test Case ID: TC-ADMIN-06
Test Case Title: Delete User Account
Description: Verify that an admin can delete a selected user account when allowed by system rules.
Precondition: A deletable user exists.
Test Data: Target user ID
Test Step:
1. Open user management.
2. Select a user.
3. Trigger delete and confirm.
Expected Result: The account is removed and no longer appears in the user listing.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-07
Test Case ID: TC-ADMIN-07
Test Case Title: Assign Adviser to Student
Description: Verify that an admin can assign an adviser to a student.
Precondition: Student and adviser accounts exist.
Test Data: Student ID; Adviser ID
Test Step:
1. Open student assignment management.
2. Select a student.
3. Assign an adviser.
4. Save.
Expected Result: The adviser assignment is stored successfully for the student.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-08
Test Case ID: TC-ADMIN-08
Test Case Title: Assign Supervisor to Student
Description: Verify that an admin can assign a supervisor to a student.
Precondition: Student and supervisor accounts exist.
Test Data: Student ID; Supervisor ID
Test Step:
1. Open student assignment management.
2. Select a student.
3. Assign a supervisor.
4. Save.
Expected Result: The supervisor assignment is stored successfully for the student.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-09
Test Case ID: TC-ADMIN-09
Test Case Title: View Current Adviser Assignment for Student
Description: Verify that an admin can retrieve the current adviser assigned to a student.
Precondition: Student already has an assigned adviser.
Test Data: Student ID
Test Step:
1. Open the selected student's assignment information.
2. Load current adviser data.
Expected Result: The system displays the correct assigned adviser.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-10
Test Case ID: TC-ADMIN-10
Test Case Title: View Current Supervisor Assignment for Student
Description: Verify that an admin can retrieve the current supervisor assigned to a student.
Precondition: Student already has an assigned supervisor.
Test Data: Student ID
Test Step:
1. Open the selected student's assignment information.
2. Load current supervisor data.
Expected Result: The system displays the correct assigned supervisor.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 13 - ROLE-BASED ACCESS, SECURITY, AND API FOUNDATION

### TC-SEC-01
Test Case ID: TC-SEC-01
Test Case Title: Student Cannot Access Supervisor Endpoints
Description: Verify that student accounts are blocked from supervisor-only routes.
Precondition: Student account is logged in.
Test Data: `GET /api/v1/supervisor/logs`
Test Step:
1. Authenticate as a student.
2. Attempt to access a supervisor-only endpoint.
Expected Result: Access is denied with an authorization error and no supervisor data is returned.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-02
Test Case ID: TC-SEC-02
Test Case Title: Adviser Cannot Create Student Logs
Description: Verify that adviser accounts cannot use student-only log creation endpoints.
Precondition: Adviser account is logged in.
Test Data: `POST /api/v1/student/logs`
Test Step:
1. Authenticate as an adviser.
2. Attempt to submit a student log payload.
Expected Result: Access is denied and the log is not created.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-03
Test Case ID: TC-SEC-03
Test Case Title: Admin Route Guard Blocks Non-Admin UI Access
Description: Verify that non-admin users are redirected away from admin-only screens.
Precondition: Student, Supervisor, or Adviser user is logged in.
Test Data: Attempt to open admin dashboard route
Test Step:
1. Log in as a non-admin user.
2. Attempt to navigate directly to the admin dashboard or assignment screen.
Expected Result: The app redirects the user to their own dashboard instead of showing admin content.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-04
Test Case ID: TC-SEC-04
Test Case Title: Protected Endpoint Requires Authentication
Description: Verify that protected API endpoints cannot be accessed without a valid token.
Precondition: User is logged out or request is sent without authentication headers.
Test Data: `GET /api/v1/notifications`
Test Step:
1. Send a request to a protected endpoint without a token.
Expected Result: The request is rejected with an unauthenticated response.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-05
Test Case ID: TC-SEC-05
Test Case Title: Health Endpoint Remains Publicly Accessible
Description: Verify that the API health endpoint is accessible without authentication.
Precondition: API server is running.
Test Data: `GET /api/v1/health`
Test Step:
1. Send a request to the health endpoint without logging in.
Expected Result: The endpoint responds successfully with the API health payload.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-06
Test Case ID: TC-SEC-06
Test Case Title: Input Sanitization Blocks Unsafe Payload
Description: Verify that unsafe script-like input is sanitized or rejected in text fields.
Precondition: User can submit a text-bearing form such as log narrative or profile field.
Test Data: `<script>alert('x')</script>`
Test Step:
1. Enter the unsafe payload into a text field.
2. Submit the form.
3. Reload the saved record if submission succeeds.
Expected Result: Unsafe input is sanitized or rejected, and executable script content is not rendered back to users.
Actual Result: Pending execution
Test Result: Not Run
