# INTERNTRACK
## Revised Test Cases by Module Feature

Reference confirmation:
- Attached file read: `Revised_Test_Cases_LNU_SMART_EVENTS_v2.docx`
- Confirmed title inside document: `LNU SMART EVENT MANAGEMENT`
- Confirmed structure inside document: module-based manual test cases with these fields:
  `TEST CASE ID`, `TEST CASE TITLE`, `DESCRIPTION`, `PRECONDITION`, `TEST DATA`, `TEST STEPS`, `EXPECTED RESULT`, `ACTUAL RESULT`, `TEST STATUS`

Alignment note:
- The attached reference document is for a SMART EVENTS system.
- The codebase in this workspace is an internship tracking system (`InternTrack`) with these implemented modules:
  Authentication, role-based access, internship profile, student logbook, file attachments, supervisor review, adviser intern list, session/auth gate, and API foundation behaviors.
- The test cases below keep the reference format but replace event-specific cases with the actual implemented features and add missing coverage not present in the reference.

---

## MODULE 1 - AUTHENTICATION AND ACCESS
### Feature: Student Registration

### TC-AUTH-01 - Successful Student Registration
Description: Verify that a new user can register successfully with valid full name, email, password, and matching password confirmation.
Precondition: User email is not yet registered.
Test Data: Name: `Juan Dela Cruz`; Email: `juan@example.com`; Password: `Password123`; Confirm Password: `Password123`
Test Steps:
1. Open the mobile app.
2. Navigate to `Create Account`.
3. Enter a valid full name.
4. Enter a valid email address.
5. Enter a password with at least 8 characters.
6. Enter the same value in `Confirm Password`.
7. Tap `REGISTER`.
Expected Result: Registration succeeds, a success message is shown, and the user is redirected to the login screen.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-02 - Duplicate Email Registration
Description: Verify that the system blocks registration when the email already exists.
Precondition: A user account already exists with the test email.
Test Data: Email: `juan@example.com`
Test Steps:
1. Open the registration screen.
2. Enter valid registration details using an existing email.
3. Tap `REGISTER`.
Expected Result: Registration is rejected and the UI displays an email-already-exists error message.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-03 - Invalid Email Format During Registration
Description: Verify that the registration form requires a properly formatted email address.
Precondition: User is on the registration screen.
Test Data: Email: `juanexample.com`
Test Steps:
1. Open the registration screen.
2. Enter a valid name.
3. Enter an invalid email format.
4. Enter valid password and confirmation values.
5. Attempt to submit the form.
Expected Result: The email field is marked invalid and registration is not submitted.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-04 - Password Minimum Length Validation
Description: Verify that the system rejects registration when the password is shorter than 8 characters.
Precondition: User is on the registration screen.
Test Data: Password: `Pass12`
Test Steps:
1. Open the registration screen.
2. Enter valid name and email values.
3. Enter a password shorter than 8 characters.
4. Enter the same short password as confirmation.
5. Attempt to submit the form.
Expected Result: The password field shows a minimum-length validation message and the register button remains disabled or submission is blocked.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-05 - Password Confirmation Mismatch
Description: Verify that registration is blocked when password and confirm password do not match.
Precondition: User is on the registration screen.
Test Data: Password: `Password123`; Confirm Password: `Password124`
Test Steps:
1. Open the registration screen.
2. Enter valid name and email values.
3. Enter a valid password.
4. Enter a different value in `Confirm Password`.
5. Attempt to submit the form.
Expected Result: The form displays `Passwords do not match` and does not proceed.
Actual Result: Pending execution
Test Status: Not Run

### Feature: Login

### TC-AUTH-06 - Successful Login
Description: Verify that a registered user can log in with valid credentials.
Precondition: A valid user account already exists.
Test Data: Email: `juan@example.com`; Password: `Password123`
Test Steps:
1. Open the login screen.
2. Enter a valid email.
3. Enter the correct password.
4. Tap `LOGIN`.
Expected Result: Login succeeds, an auth token is stored, and the user is redirected to the correct dashboard based on role.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-07 - Login with Invalid Credentials
Description: Verify that the system rejects login when the password is incorrect.
Precondition: A valid user account already exists.
Test Data: Email: `juan@example.com`; Password: `WrongPass123`
Test Steps:
1. Open the login screen.
2. Enter a valid email.
3. Enter an incorrect password.
4. Tap `LOGIN`.
Expected Result: Login fails and the system displays `Invalid credentials`.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-08 - Login Validation for Invalid or Empty Email
Description: Verify that the login form requires a valid email before submission.
Precondition: User is on the login screen.
Test Data: Email: blank or `juanexample.com`
Test Steps:
1. Open the login screen.
2. Leave the email blank or enter an invalid email format.
3. Enter any password.
4. Attempt to submit.
Expected Result: The email field shows validation feedback and login is not processed.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-09 - Login Validation for Empty or Short Password
Description: Verify that the login form requires a password and enforces the minimum length rule.
Precondition: User is on the login screen.
Test Data: Password: blank or `short1`
Test Steps:
1. Open the login screen.
2. Enter a valid email.
3. Leave the password blank or enter fewer than 8 characters.
4. Attempt to submit.
Expected Result: The password field shows validation feedback and login is not processed.
Actual Result: Pending execution
Test Status: Not Run

### Feature: Session and Logout

### TC-AUTH-10 - Auth Gate Redirect for Authenticated User
Description: Verify that the app automatically redirects an authenticated user to the correct dashboard on app open.
Precondition: A valid auth token is already stored in secure storage.
Test Data: Stored token for Student, Supervisor, or Adviser account
Test Steps:
1. Close the app completely.
2. Reopen the app.
3. Observe the startup flow from the auth gate screen.
Expected Result: The app skips the login screen and redirects the user to the dashboard that matches the stored user's role.
Actual Result: Pending execution
Test Status: Not Run

### TC-AUTH-11 - Logout Clears Session
Description: Verify that logout removes the stored auth token and returns the user to the login screen.
Precondition: User is already logged in.
Test Data: Any valid authenticated session
Test Steps:
1. Log in to the app.
2. Open the dashboard.
3. Tap the logout icon.
4. Relaunch or refresh the app.
Expected Result: The user is returned to the login screen and protected screens are no longer accessible without logging in again.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 2 - ROLE-BASED ACCESS CONTROL

### TC-RBAC-01 - Student Cannot Access Supervisor API Routes
Description: Verify that a student account cannot access supervisor-protected endpoints.
Precondition: Student user is logged in and has a valid token.
Test Data: `GET /api/v1/supervisor/logs`
Test Steps:
1. Authenticate as a Student user.
2. Attempt to access a supervisor-only endpoint.
Expected Result: Access is denied with HTTP 403 and no supervisor data is returned.
Actual Result: Pending execution
Test Status: Not Run

### TC-RBAC-02 - Adviser Cannot Access Student Log Creation Endpoint
Description: Verify that a non-student user cannot create student log entries.
Precondition: Adviser user is logged in and has a valid token.
Test Data: `POST /api/v1/student/logs`
Test Steps:
1. Authenticate as an Adviser user.
2. Submit a valid student log payload to the student log endpoint.
Expected Result: Access is denied with HTTP 403.
Actual Result: Pending execution
Test Status: Not Run

### TC-RBAC-03 - Route Guard Redirects Wrong Role to Correct Dashboard
Description: Verify that the Flutter route guard prevents users from opening dashboard routes that do not match their role.
Precondition: User is logged in as Student, Supervisor, or Adviser.
Test Data: Try opening another role's dashboard route
Test Steps:
1. Log in as a Student user.
2. Attempt to navigate directly to the supervisor or adviser dashboard route.
3. Repeat with Supervisor and Adviser users against other dashboard routes.
Expected Result: The app redirects the user back to their own dashboard instead of showing the unauthorized dashboard.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 3 - INTERNSHIP PROFILE MANAGEMENT
### Feature: Create and View Internship Profile

### TC-PROF-01 - Successful Internship Profile Creation
Description: Verify that a student can create an internship profile with complete and valid data.
Precondition: Student is logged in and does not yet have an internship profile.
Test Data: Company Name: `Acme Corp`; Company Address: `Tacloban City`; Required Hours: `486`; Start Date: `2026-03-01`; End Date: `2026-06-30`
Test Steps:
1. Log in as a Student user.
2. Open `Internship Profile`.
3. Enter complete and valid profile data.
4. Tap `Create Internship Profile`.
Expected Result: Profile is created successfully and the screen changes to a summary view showing the stored details.
Actual Result: Pending execution
Test Status: Not Run

### TC-PROF-02 - Required Field Validation
Description: Verify that the internship profile form rejects submission when required fields are blank.
Precondition: Student is logged in and has no existing profile.
Test Data: One or more blank fields
Test Steps:
1. Open the internship profile form.
2. Leave `Company Name`, `Company Address`, `Required Hours`, `Start Date`, or `End Date` blank.
3. Attempt to submit.
Expected Result: Required-field validation messages are displayed and the profile is not created.
Actual Result: Pending execution
Test Status: Not Run

### TC-PROF-03 - Required Hours Must Be Greater Than Zero
Description: Verify that the form rejects zero, negative, or non-numeric values for required hours.
Precondition: Student is on the internship profile form.
Test Data: `0`, `-1`, `abc`
Test Steps:
1. Open the internship profile form.
2. Enter valid values in all fields except `Required Hours`.
3. Test zero, negative, and non-numeric values.
4. Attempt to submit each variation.
Expected Result: The form shows `Required hours must be greater than 0` or equivalent validation feedback and blocks submission.
Actual Result: Pending execution
Test Status: Not Run

### TC-PROF-04 - End Date Must Be After Start Date
Description: Verify that the system rejects an internship profile whose end date is on or before the start date.
Precondition: Student is on the internship profile form.
Test Data: Start Date: `2026-06-01`; End Date: `2026-06-01` or `2026-05-31`
Test Steps:
1. Open the internship profile form.
2. Enter valid company details and required hours.
3. Enter an end date equal to or earlier than the start date.
4. Attempt to submit.
Expected Result: The form shows `End date must be after start date` and prevents profile creation.
Actual Result: Pending execution
Test Status: Not Run

### TC-PROF-05 - Duplicate Internship Profile Rejection
Description: Verify that the backend rejects creation of a second internship profile for the same student.
Precondition: Student already has an existing internship profile.
Test Data: Any second valid profile payload
Test Steps:
1. Create an internship profile successfully.
2. Attempt to submit another profile for the same student.
Expected Result: The request is rejected with a duplicate/conflict response and no second profile is created.
Actual Result: Pending execution
Test Status: Not Run

### TC-PROF-06 - Existing Profile Summary Retrieval
Description: Verify that a student with an existing profile sees the stored profile summary instead of the creation form.
Precondition: Student already has an internship profile.
Test Data: Existing stored profile
Test Steps:
1. Log in as a Student user with an existing profile.
2. Open `Internship Profile`.
Expected Result: The app loads and displays the saved company, address, required hours, dates, supervisor ID, and adviser ID if available.
Actual Result: Pending execution
Test Status: Not Run

### TC-PROF-07 - No Existing Profile Error Handling
Description: Verify that profile retrieval handles the no-profile state correctly and still allows a new profile to be created.
Precondition: Student is logged in and has no profile yet.
Test Data: None
Test Steps:
1. Open `Internship Profile` for a student with no existing record.
2. Observe the initial load behavior.
3. Use the displayed form to create a valid profile.
Expected Result: The screen either exposes the create form directly or shows a recoverable state that still allows profile creation.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 4 - STUDENT LOGBOOK MANAGEMENT
### Feature: Create, View, List, and Edit Logs

### TC-LOG-01 - Successful Daily Log Submission
Description: Verify that a student can submit a daily log with valid date, hours, and task description.
Precondition: Student is logged in and already has an internship profile.
Test Data: Date: current date or earlier; Hours: `8`; Task Description: `Prepared documentation and updated project tasks.`
Test Steps:
1. Open `My Logs`.
2. Enter a valid date not later than today.
3. Enter valid hours between 1 and 12.
4. Enter a task description.
5. Tap `Submit Log`.
Expected Result: The log is saved with `PENDING` status, a success message appears, and the new entry is listed in the logbook.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-02 - Log Submission Without Internship Profile
Description: Verify that the system rejects log creation when the student has no internship profile yet.
Precondition: Student is logged in but has no internship profile.
Test Data: Any otherwise valid log payload
Test Steps:
1. Authenticate as a student without an internship profile.
2. Attempt to submit a daily log.
Expected Result: The request fails and the system informs the user that an internship profile is required before submitting logs.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-03 - Future Log Date Rejection
Description: Verify that the system rejects log entries with a future date.
Precondition: Student has an internship profile and is on the logbook screen.
Test Data: Date: tomorrow
Test Steps:
1. Open the logbook create form.
2. Attempt to select or submit a date later than today.
3. Fill the remaining fields with valid values.
4. Submit the form.
Expected Result: The form shows `Future dates are not allowed` or the API returns `Log date cannot be in the future`, and the log is not created.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-04 - Hours Rendered Boundary Validation
Description: Verify that only whole-number hours from 1 to 12 are accepted.
Precondition: Student is on the logbook create form.
Test Data: `0`, `13`, `abc`
Test Steps:
1. Enter a valid date and task description.
2. Test invalid hours values one at a time.
3. Attempt to submit for each case.
Expected Result: Invalid values are rejected and the UI displays `Hours must be between 1 and 12` or `Hours must be a number`.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-05 - Duplicate Log Date Rejection
Description: Verify that the system prevents a student from creating two logs for the same date.
Precondition: Student already has a saved log for the target date.
Test Data: Existing date with another log
Test Steps:
1. Create a valid log for a specific date.
2. Attempt to create a second log using the same date.
Expected Result: The system rejects the duplicate entry and displays `A log already exists for this date.`
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-06 - Log List Order and Attachment Metadata
Description: Verify that log entries are listed from newest to oldest and show attachment count metadata.
Precondition: Student has multiple logs, including at least one with an attachment.
Test Data: Two or more logs with different dates
Test Steps:
1. Open `My Logs`.
2. Observe the order of listed entries.
3. Check the `Attachments` count for each item.
Expected Result: Logs are sorted newest first, and each list item shows the correct attachment count and status.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-07 - View Own Log Details
Description: Verify that a student can open and view the full details of their own log entry.
Precondition: Student has at least one log entry.
Test Data: Existing owned log
Test Steps:
1. Open `My Logs`.
2. Tap `Details` on one log entry.
Expected Result: The detail screen shows full log data including date, hours, task description, status, attachments, and review history if present.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-08 - Access Another Student's Log Is Forbidden
Description: Verify that one student cannot access another student's log details through the API.
Precondition: Two student accounts exist and each has a profile; one student owns the target log.
Test Data: `GET /api/v1/student/logs/{otherStudentLogId}`
Test Steps:
1. Log in as Student B.
2. Attempt to access Student A's log by ID.
Expected Result: The request is rejected with HTTP 403 and no log data is returned.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-09 - Successful Edit of Pending Log
Description: Verify that a student can update a log only while it is still in `PENDING` status.
Precondition: Student owns a log with status `PENDING`.
Test Data: Updated date, hours, and task description
Test Steps:
1. Open a pending log.
2. Tap `Edit`.
3. Change the values to another valid set.
4. Save the changes.
Expected Result: The log updates successfully and the list reflects the edited values.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-10 - Editing Approved or Rejected Log Is Blocked
Description: Verify that non-pending logs cannot be edited.
Precondition: Student owns a log with status `APPROVED` or `REJECTED`.
Test Data: Existing reviewed log
Test Steps:
1. Open a reviewed log from the list or attempt the edit API directly.
2. Try to modify the log.
Expected Result: The UI blocks editing or the API returns an error stating that only pending logs can be edited.
Actual Result: Pending execution
Test Status: Not Run

### TC-LOG-11 - Edit Log to a Duplicate Date Is Rejected
Description: Verify that updating a pending log to a date already used by another log for the same student is blocked.
Precondition: Student has two logs on different dates and both belong to the same internship profile.
Test Data: Change Log B date to Log A date
Test Steps:
1. Open one pending log for editing.
2. Change its date to a date already used by another log.
3. Save the changes.
Expected Result: The update is rejected with `A log already exists for this date.`
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 5 - LOG ATTACHMENTS
### Feature: Attachment Upload and Validation

### TC-ATT-01 - Submit Log Successfully Without Attachment
Description: Verify that attachment upload is optional when creating a new daily log.
Precondition: Student has an internship profile and is on the create-log form.
Test Data: Valid date, hours, and task description with no file selected
Test Steps:
1. Open `My Logs`.
2. Fill out the create-log form with valid data.
3. Leave the attachment field empty.
4. Submit the log.
Expected Result: The log is created successfully even without an attachment.
Actual Result: Pending execution
Test Status: Not Run

### TC-ATT-02 - Upload Allowed Attachment Types
Description: Verify that valid `jpg`, `jpeg`, `png`, and `pdf` files can be uploaded to a pending log.
Precondition: Student owns a pending log.
Test Data: `proof.jpg`, `proof.jpeg`, `proof.png`, `proof.pdf`
Test Steps:
1. Open a pending log or use the `Upload Proof` action.
2. Upload each supported file type in separate runs.
Expected Result: Each allowed file type uploads successfully and the attachment count increases.
Actual Result: Pending execution
Test Status: Not Run

### TC-ATT-03 - Unsupported Attachment Type Rejection
Description: Verify that the system rejects files outside the allowed extensions list.
Precondition: Student owns a pending log.
Test Data: `malware.exe`
Test Steps:
1. Open a pending log attachment flow.
2. Select an unsupported file type.
3. Attempt to upload.
Expected Result: The upload is rejected and the system displays an invalid file type message.
Actual Result: Pending execution
Test Status: Not Run

### TC-ATT-04 - Attachment Size Limit Validation
Description: Verify that files larger than 5MB are rejected.
Precondition: Student owns a pending log.
Test Data: `large.pdf` larger than 5MB
Test Steps:
1. Open the attachment upload flow.
2. Select a valid file type larger than 5MB.
3. Attempt to upload.
Expected Result: The system rejects the upload and displays `File too large. Maximum size is 5MB.` or equivalent UI feedback.
Actual Result: Pending execution
Test Status: Not Run

### TC-ATT-05 - Upload Attachment to Another Student's Log Is Forbidden
Description: Verify that a student cannot upload attachments to a log they do not own.
Precondition: Two students exist; Student A owns the target log and Student B is authenticated.
Test Data: Valid `proof.pdf`
Test Steps:
1. Log in as Student B.
2. Attempt to upload an attachment to Student A's log ID.
Expected Result: The request is rejected with HTTP 403 and no file is stored.
Actual Result: Pending execution
Test Status: Not Run

### TC-ATT-06 - Upload to Approved or Rejected Log Is Blocked
Description: Verify that attachments can only be added while a log is still pending.
Precondition: Student owns a log in `APPROVED` or `REJECTED` status.
Test Data: Valid `proof.pdf`
Test Steps:
1. Open a reviewed log.
2. Attempt to upload an attachment.
Expected Result: The system blocks the upload and informs the user that attachments can only be added to pending logs.
Actual Result: Pending execution
Test Status: Not Run

### TC-ATT-07 - Browser Picker Cancel Handling
Description: Verify that the web/mobile file picker handles a canceled file selection gracefully.
Precondition: Student is on the logbook screen.
Test Data: Cancel file selection without choosing a file
Test Steps:
1. Tap `Choose File` or `Upload Proof`.
2. Cancel the file picker.
3. Return to the app.
Expected Result: The app does not crash; existing form data remains intact; if applicable, the UI shows a non-destructive message and no upload occurs.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 6 - SUPERVISOR REVIEW WORKFLOW
### Feature: Pending Log Queue, Detail View, Approval, and Rejection

### TC-SUP-01 - Supervisor Sees Only Assigned Pending Logs
Description: Verify that a supervisor only sees pending logs from students assigned to them.
Precondition: Multiple students and supervisors exist; some logs are pending and some are already reviewed.
Test Data: Assigned and unassigned student logs
Test Steps:
1. Log in as a Supervisor user.
2. Open `Review Pending Logs`.
3. Observe the queue.
Expected Result: Only logs belonging to the supervisor's assigned students appear, and only those with `PENDING` status are listed.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-02 - Supervisor Queue Is Sorted Oldest First
Description: Verify that the pending review queue sorts logs by oldest date first.
Precondition: Supervisor has at least two assigned pending logs on different dates.
Test Data: Older pending log and newer pending log
Test Steps:
1. Open the supervisor pending log queue.
2. Compare the order of displayed dates.
Expected Result: Older pending logs are shown first, followed by newer pending logs.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-03 - Supervisor Can View Assigned Log Details
Description: Verify that a supervisor can open an assigned log and see student info, attachments, and review history.
Precondition: Supervisor has an assigned student log.
Test Data: Assigned log with at least one attachment and one review action if available
Test Steps:
1. Open the pending log queue.
2. Select an assigned log.
Expected Result: The detail screen displays student name, email, company, log details, attachments, and review history.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-04 - Supervisor Cannot View Unassigned Log
Description: Verify that a supervisor cannot access a log belonging to another supervisor's student.
Precondition: The target log belongs to a different supervisor.
Test Data: `GET /api/v1/supervisor/logs/{unassignedLogId}`
Test Steps:
1. Authenticate as Supervisor A.
2. Attempt to access Supervisor B's assigned log by ID.
Expected Result: The request is rejected with HTTP 403 and no log details are returned.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-05 - Successful Log Approval
Description: Verify that a supervisor can approve an assigned pending log.
Precondition: Supervisor owns an assigned pending log.
Test Data: Optional comment: `Great progress on the assigned tasks.`
Test Steps:
1. Open an assigned pending log.
2. Optionally enter a comment.
3. Tap `Approve`.
Expected Result: The log status changes to `APPROVED`, a success message appears, and a review-history record is created.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-06 - Successful Log Rejection with Comment
Description: Verify that a supervisor can reject an assigned pending log when a comment is provided.
Precondition: Supervisor owns an assigned pending log.
Test Data: Comment: `Please attach proof of work before resubmitting.`
Test Steps:
1. Open an assigned pending log.
2. Enter a rejection comment.
3. Tap `Reject`.
Expected Result: The log status changes to `REJECTED`, a success message appears, and the review history stores the rejection comment.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-07 - Rejection Without Comment Is Blocked
Description: Verify that a supervisor cannot reject a pending log without entering a comment.
Precondition: Supervisor owns an assigned pending log.
Test Data: Empty comment
Test Steps:
1. Open an assigned pending log.
2. Leave the comment field empty.
3. Tap `Reject`.
Expected Result: The UI or API blocks the action and displays that a comment is required before rejecting.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-08 - Already Reviewed Log Cannot Be Re-Approved or Re-Rejected
Description: Verify that only pending logs can be reviewed.
Precondition: Supervisor owns an assigned log already marked `APPROVED` or `REJECTED`.
Test Data: Existing reviewed log
Test Steps:
1. Attempt to approve or reject the already reviewed log.
Expected Result: The action is rejected with a conflict message such as `Only PENDING logs can be approved` or `Only PENDING logs can be rejected`.
Actual Result: Pending execution
Test Status: Not Run

### TC-SUP-09 - Empty Queue State for Supervisor with No Assigned Interns
Description: Verify that the supervisor queue handles the no-data state correctly.
Precondition: Supervisor account exists but has no assigned internship profiles or pending logs.
Test Data: None
Test Steps:
1. Log in as a Supervisor with no assigned students.
2. Open `Review Pending Logs`.
Expected Result: The queue loads successfully and displays an empty state rather than an error.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 7 - ADVISER INTERN LIST
### Feature: Adviser and Supervisor Assigned Intern Views

### TC-ADV-01 - Adviser Can View Assigned Intern List
Description: Verify that an adviser can retrieve and view interns assigned to them.
Precondition: Adviser account has at least one internship profile assigned.
Test Data: Assigned student profiles
Test Steps:
1. Log in as an Adviser user.
2. Open `View Assigned Interns`.
Expected Result: The list displays assigned student names, company names, and required hours.
Actual Result: Pending execution
Test Status: Not Run

### TC-ADV-02 - Adviser Empty State
Description: Verify that the adviser screen shows a clean empty state when no interns are assigned.
Precondition: Adviser exists with no assigned internship profiles.
Test Data: None
Test Steps:
1. Log in as an Adviser user with no assigned interns.
2. Open the intern list screen.
Expected Result: The screen loads successfully and displays `No assigned interns found.`
Actual Result: Pending execution
Test Status: Not Run

### TC-ADV-03 - Supervisor Can View Assigned Intern List
Description: Verify that a supervisor can open and view their assigned interns from the dashboard.
Precondition: Supervisor has at least one assigned internship profile.
Test Data: Assigned student profiles
Test Steps:
1. Log in as a Supervisor user.
2. Open `View Assigned Interns`.
Expected Result: The list shows only interns assigned to the logged-in supervisor.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 8 - DASHBOARD AND NAVIGATION

### TC-DASH-01 - Student Dashboard Displays Internship Prompt Without Profile
Description: Verify that the student dashboard shows the no-profile prompt when there is no internship profile yet.
Precondition: Student is logged in without an internship profile.
Test Data: None
Test Steps:
1. Log in as a Student user without a profile.
2. Observe the dashboard cards.
Expected Result: The dashboard shows the message `No internship profile yet. Add your profile to unlock tracking.`
Actual Result: Pending execution
Test Status: Not Run

### TC-DASH-02 - Student Dashboard Navigation to Logbook and Internship Profile
Description: Verify that dashboard buttons route the student to the correct screens.
Precondition: Student is logged in.
Test Data: None
Test Steps:
1. Open the student dashboard.
2. Tap `Open Logbook`.
3. Return to the dashboard.
4. Tap `Internship Profile`.
Expected Result: Each action opens the correct screen without error.
Actual Result: Pending execution
Test Status: Not Run

### TC-DASH-03 - Supervisor Dashboard Navigation
Description: Verify that the supervisor dashboard opens the assigned intern list and pending log review screens.
Precondition: Supervisor is logged in.
Test Data: None
Test Steps:
1. Open the supervisor dashboard.
2. Tap `View Assigned Interns`.
3. Return to the dashboard.
4. Tap `Review Pending Logs`.
Expected Result: Each button opens the correct screen.
Actual Result: Pending execution
Test Status: Not Run

### TC-DASH-04 - Adviser Dashboard Navigation
Description: Verify that the adviser dashboard opens the assigned intern list screen.
Precondition: Adviser is logged in.
Test Data: None
Test Steps:
1. Open the adviser dashboard.
2. Tap `View Assigned Interns`.
Expected Result: The adviser intern list screen opens successfully.
Actual Result: Pending execution
Test Status: Not Run

---

## MODULE 9 - API FOUNDATION AND ERROR HANDLING

### Feature: Admin Student Adviser Assignment

### TC-ADM-01 - Admin Can Load Adviser Directory for Assignment
Description: Verify that the admin adviser-assignment screen can load available adviser options before assigning.
Precondition: Adviser accounts exist.
Test Data: `GET /api/v1/admin/advisers`
Test Steps:
1. Log in as an Admin user.
2. Open `Manage Student Advisers`.
3. Observe adviser dropdown options or call the advisers endpoint directly.
Expected Result: The adviser list should load normally and include adviser accounts only.
Actual Result: This could not be completed because the API returned HTTP `500`. Error from backend setup: `SQLSTATE[HY000]: Field 'company_address' doesn't have a default value`.
Test Status: Failed

### TC-ADM-02 - Admin Can View Current Adviser for a Student
Description: Verify that admin can retrieve the currently assigned adviser for a selected student.
Precondition: Student has an internship profile with adviser assignment.
Test Data: `GET /api/v1/admin/students/{studentId}/adviser`
Test Steps:
1. Log in as an Admin user.
2. Open `Manage Student Advisers`.
3. Select a student with existing adviser assignment.
Expected Result: The screen/API should return the student's current adviser name and ID correctly.
Actual Result: The check failed before adviser lookup. Test setup hit HTTP `500` while creating profile data because `company_address` has no default value.
Test Status: Failed

### TC-ADM-03 - Admin Can Assign or Change Adviser for a Student
Description: Verify that admin can assign a new adviser or reassign to a different adviser for a student.
Precondition: At least two adviser accounts exist and a student profile exists.
Test Data: `PATCH /api/v1/admin/students/{studentId}/assign-adviser` with valid `adviser_id`
Test Steps:
1. Log in as an Admin user.
2. Open `Manage Student Advisers`.
3. Choose a student and select an adviser.
4. Save assignment, then repeat with a different adviser.
Expected Result: Adviser assignment should save successfully, persist in the database, and return success feedback.
Actual Result: Assignment flow was blocked by an earlier HTTP `500` during setup. Backend failed on profile insert due to missing default for `company_address`.
Test Status: Failed

### TC-ADM-04 - Admin Can Remove Adviser Assignment
Description: Verify that admin can remove an existing adviser assignment from a student.
Precondition: Student currently has an assigned adviser.
Test Data: `PATCH /api/v1/admin/students/{studentId}/assign-adviser` with `adviser_id: null`
Test Steps:
1. Log in as an Admin user.
2. Open `Manage Student Advisers`.
3. Select `None (Remove adviser)` and save.
Expected Result: Existing adviser assignment should be removed and the student should appear as unassigned.
Actual Result: Could not validate removal because the request path failed upstream with HTTP `500` while preparing profile data (`company_address` default issue).
Test Status: Failed

### TC-ADM-05 - Non-Admin Cannot Use Adviser Assignment Endpoints
Description: Verify that adviser-assignment endpoints are protected from non-admin roles.
Precondition: Authenticated Student, Supervisor, or Adviser account exists.
Test Data: Student/Supervisor/Adviser token
Test Steps:
1. Authenticate as a non-admin user.
2. Call `GET /api/v1/admin/advisers`.
3. Call `GET /api/v1/admin/students/{studentId}/adviser`.
4. Call `PATCH /api/v1/admin/students/{studentId}/assign-adviser`.
Expected Result: Non-admin requests should be denied consistently with HTTP `403`.
Actual Result: Validation was incomplete. The suite encountered a setup SQL error (`company_address` missing default) before all authorization scenarios could run.
Test Status: Failed

---

## MODULE 10 - API FOUNDATION AND ERROR HANDLING

### TC-API-01 - Health Endpoint Returns Expected Payload
Description: Verify that the API health endpoint returns a successful response and timestamp.
Precondition: Backend API is running.
Test Data: `GET /api/v1/health`
Test Steps:
1. Send a request to the API health endpoint.
2. Inspect the JSON response.
Expected Result: Response status is 200 with `success: true`, message `API is running`, and a timestamp field.
Actual Result: Pending execution
Test Status: Not Run

### TC-API-02 - Missing API Route Returns Standardized 404 JSON
Description: Verify that unknown API routes return the standardized not-found response format.
Precondition: Backend API is running.
Test Data: `GET /api/v1/does-not-exist`
Test Steps:
1. Send a request to a non-existent API route under `/api/v1`.
2. Inspect the response body.
Expected Result: The API returns HTTP 404 with JSON containing `success: false`, `message: Resource not found.`, and `data: null`.
Actual Result: Pending execution
Test Status: Not Run

---

## Coverage Added Beyond the Reference File

The attached SMART EVENTS reference did not cover these implemented InternTrack features, which are now included in this revised set:
- Internship profile creation and duplicate-profile protection
- Student daily logbook creation, listing, detail, and edit rules
- Duplicate log-date protection
- Optional and post-submission attachment uploads
- Allowed file-type and file-size attachment validation
- Supervisor pending queue, detail view, approval, rejection, and review history
- Adviser and supervisor assigned intern list views
- Role-based route/API protection
- Auth gate, token persistence, and logout behavior
- API health check and standardized 404 response validation
