# INTERNTRACK
## Expanded Manual Test Cases by Module

Document note:
- This version expands coverage for the whole system by module.
- It includes both success and failure or reverse test cases.
- `Actual Result` is set to `Pending execution`.
- `Test Result` is set to `Not Run`.

---

## MODULE 1 - AUTHENTICATION AND SESSION

### TC-AUTH-01
Test Case ID: TC-AUTH-01
TestCase Title: Successful Student Registration
Descrption: Verify that a new student can register using valid data.
Precondition: The email address is not yet registered.
Test data: Name `Juan Dela Cruz`; Email `juan@example.com`; Password `Password123`; Confirm Password `Password123`
Test Step:
1. Open the app.
2. Navigate to `Create Account`.
3. Enter valid registration data.
4. Tap `Register`.
Expected Result: Registration succeeds and the user is redirected to the login screen.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-02
Test Case ID: TC-AUTH-02
TestCase Title: Registration Using Existing Email
Descrption: Verify that registration fails when the email is already used.
Precondition: An existing account already uses `juan@example.com`.
Test data: Name `Juan Dela Cruz`; Email `juan@example.com`; Password `Password123`
Test Step:
1. Open the registration screen.
2. Enter valid values using an existing email.
3. Submit the form.
Expected Result: Registration is rejected and an email already exists message is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-03
Test Case ID: TC-AUTH-03
TestCase Title: Registration with Invalid Email Format
Descrption: Verify that registration does not allow an invalid email format.
Precondition: User is on the registration form.
Test data: Email `juanexample.com`
Test Step:
1. Fill in a valid full name.
2. Enter an invalid email format.
3. Enter valid password fields.
4. Submit the form.
Expected Result: The form is not submitted and the email field shows validation feedback.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-04
Test Case ID: TC-AUTH-04
TestCase Title: Registration with Blank Required Fields
Descrption: Verify that registration fails when required fields are blank.
Precondition: User is on the registration form.
Test data: Blank name; blank email; blank password
Test Step:
1. Open `Create Account`.
2. Leave one or more required fields empty.
3. Tap `Register`.
Expected Result: Validation errors are shown and registration is blocked.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-05
Test Case ID: TC-AUTH-05
TestCase Title: Registration with Short Password
Descrption: Verify that registration rejects a password shorter than the minimum required length.
Precondition: User is on the registration form.
Test data: Password `Pass12`; Confirm Password `Pass12`
Test Step:
1. Enter valid name and email.
2. Enter a short password.
3. Submit the form.
Expected Result: Registration is blocked and a password length validation message is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-06
Test Case ID: TC-AUTH-06
TestCase Title: Registration with Password Mismatch
Descrption: Verify that registration fails when password and confirmation do not match.
Precondition: User is on the registration form.
Test data: Password `Password123`; Confirm Password `Password124`
Test Step:
1. Enter valid name and email.
2. Enter mismatched password values.
3. Tap `Register`.
Expected Result: Registration is blocked and a password mismatch message is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-07
Test Case ID: TC-AUTH-07
TestCase Title: Successful Login
Descrption: Verify that a valid user can log in successfully.
Precondition: A registered user account exists.
Test data: Email `student@example.com`; Password `Password123`
Test Step:
1. Open the login screen.
2. Enter valid credentials.
3. Tap `Login`.
Expected Result: Login succeeds and the user is redirected to the proper dashboard.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-08
Test Case ID: TC-AUTH-08
TestCase Title: Login with Wrong Password
Descrption: Verify that login fails when the password is incorrect.
Precondition: A registered user account exists.
Test data: Email `student@example.com`; Password `WrongPass123`
Test Step:
1. Open the login screen.
2. Enter a valid email and incorrect password.
3. Tap `Login`.
Expected Result: Login fails and an invalid credentials message is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-09
Test Case ID: TC-AUTH-09
TestCase Title: Login with Unregistered Email
Descrption: Verify that login fails when the email is not registered.
Precondition: The test email does not exist in the system.
Test data: Email `nouser@example.com`; Password `Password123`
Test Step:
1. Open the login screen.
2. Enter an unregistered email and valid password format.
3. Tap `Login`.
Expected Result: Login is rejected and the user remains on the login screen.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-10
Test Case ID: TC-AUTH-10
TestCase Title: Login with Blank Fields
Descrption: Verify that login cannot proceed with missing required fields.
Precondition: User is on the login screen.
Test data: Blank email; blank password
Test Step:
1. Leave email and or password blank.
2. Tap `Login`.
Expected Result: Validation messages are shown and login is blocked.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-11
Test Case ID: TC-AUTH-11
TestCase Title: Role-Based Redirect After Login
Descrption: Verify that each role opens the correct dashboard after login.
Precondition: Valid Student, Supervisor, Adviser, and Admin accounts exist.
Test data: Credentials for all four roles
Test Step:
1. Log in as Student.
2. Observe the landing page.
3. Repeat for Supervisor, Adviser, and Admin.
Expected Result: Each user is routed to the dashboard assigned to their role.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-12
Test Case ID: TC-AUTH-12
TestCase Title: Restore Session on App Relaunch
Descrption: Verify that an authenticated session is restored after reopening the app.
Precondition: A valid token is stored locally.
Test data: Existing active session
Test Step:
1. Log in successfully.
2. Close the app completely.
3. Reopen the app.
Expected Result: The app bypasses guest pages and opens the correct protected dashboard.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-13
Test Case ID: TC-AUTH-13
TestCase Title: Logout Clears Session
Descrption: Verify that logout removes the current authenticated session.
Precondition: User is logged in.
Test data: Valid active session
Test Step:
1. Tap the logout action.
2. Attempt to reopen a protected page.
Expected Result: The session is cleared and the user is sent back to the login screen.
Actual Result: Pending execution
Test Result: Not Run

### TC-AUTH-14
Test Case ID: TC-AUTH-14
TestCase Title: Protected Route Access After Logout
Descrption: Verify that a logged-out user cannot access protected routes using browser refresh or manual route entry.
Precondition: User has already logged out.
Test data: Protected route such as `/student-dashboard`
Test Step:
1. Logout from the app.
2. Try to reopen a protected route directly.
Expected Result: Access is denied and the login screen is shown.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 2 - ACCOUNT PROFILE AND SETTINGS

### TC-ACC-01
Test Case ID: TC-ACC-01
TestCase Title: View Current User Profile
Descrption: Verify that a logged-in user can view their profile information.
Precondition: User is authenticated.
Test data: Any valid account
Test Step:
1. Log in to the app.
2. Open settings or profile.
3. Load account data.
Expected Result: The correct user profile information is displayed.
Actual Result: Pending execution
Test Result: Not Run

### TC-ACC-02
Test Case ID: TC-ACC-02
TestCase Title: Update User Profile
Descrption: Verify that a user can update their editable profile fields.
Precondition: User is authenticated.
Test data: Updated name `Juan Updated`; Gender `Male`
Test Step:
1. Open profile settings.
2. Edit profile fields.
3. Save the changes.
4. Reload the page.
Expected Result: The profile updates are saved and displayed correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-ACC-03
Test Case ID: TC-ACC-03
TestCase Title: Update Profile with Blank Name
Descrption: Verify that the profile update is blocked when a required field like name is blank.
Precondition: User is on the profile update screen.
Test data: Blank name
Test Step:
1. Delete the current name value.
2. Tap save.
Expected Result: The update is blocked and a validation message is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-ACC-04
Test Case ID: TC-ACC-04
TestCase Title: Upload Valid Avatar Image
Descrption: Verify that a valid avatar file can be uploaded successfully.
Precondition: User is authenticated and has a valid image file.
Test data: File `avatar.jpg`
Test Step:
1. Open the avatar update control.
2. Choose a valid image file.
3. Submit the upload.
Expected Result: The avatar is uploaded and displayed in the app.
Actual Result: Pending execution
Test Result: Not Run

### TC-ACC-05
Test Case ID: TC-ACC-05
TestCase Title: Upload Unsupported Avatar File
Descrption: Verify that unsupported avatar file types are rejected.
Precondition: User is authenticated.
Test data: File `avatar.txt`
Test Step:
1. Open avatar upload.
2. Choose an unsupported file type.
3. Submit.
Expected Result: The upload is rejected and an error is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-ACC-06
Test Case ID: TC-ACC-06
TestCase Title: Persist Theme Preference
Descrption: Verify that theme preference remains saved after app restart.
Precondition: Settings screen is accessible.
Test data: Theme mode `Dark`
Test Step:
1. Open settings.
2. Change the theme.
3. Close and reopen the app.
Expected Result: The chosen theme remains active after relaunch.
Actual Result: Pending execution
Test Result: Not Run

### TC-ACC-07
Test Case ID: TC-ACC-07
TestCase Title: Access Settings While Logged Out
Descrption: Verify that a logged-out user cannot access settings.
Precondition: User is not authenticated.
Test data: Settings route
Test Step:
1. Open the settings route directly while logged out.
Expected Result: The user is redirected to the login screen.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 3 - NOTIFICATIONS

### TC-NOTIF-01
Test Case ID: TC-NOTIF-01
TestCase Title: View Notification List
Descrption: Verify that a user can view their own notifications.
Precondition: The user has existing notifications.
Test data: Read and unread notifications
Test Step:
1. Log in to the app.
2. Open the notification list.
Expected Result: Only the current user's notifications are displayed, ordered by newest first.
Actual Result: Pending execution
Test Result: Not Run

### TC-NOTIF-02
Test Case ID: TC-NOTIF-02
TestCase Title: Notification List When No Notifications Exist
Descrption: Verify that the app handles an empty notification list correctly.
Precondition: The user has no notifications.
Test data: Empty notification set
Test Step:
1. Log in as a user with no notifications.
2. Open the notification list.
Expected Result: The app shows an empty state without errors.
Actual Result: Pending execution
Test Result: Not Run

### TC-NOTIF-03
Test Case ID: TC-NOTIF-03
TestCase Title: Mark Owned Notification as Read
Descrption: Verify that the user can mark their own unread notification as read.
Precondition: The user has an unread notification.
Test data: Valid owned notification ID
Test Step:
1. Open the notifications list.
2. Mark one unread notification as read.
3. Refresh the list.
Expected Result: The notification changes to read and unread count decreases.
Actual Result: Pending execution
Test Result: Not Run

### TC-NOTIF-04
Test Case ID: TC-NOTIF-04
TestCase Title: Mark Already Read Notification
Descrption: Verify that marking an already read notification does not cause an error or duplicate state issue.
Precondition: The user has at least one already read notification.
Test data: Already read notification ID
Test Step:
1. Open notifications.
2. Mark an already read notification again if the UI allows it.
Expected Result: The system keeps the notification in read state and no incorrect count change occurs.
Actual Result: Pending execution
Test Result: Not Run

### TC-NOTIF-05
Test Case ID: TC-NOTIF-05
TestCase Title: Open Notification Linked to Log
Descrption: Verify that tapping a log-related notification opens the related screen.
Precondition: Student has a notification linked to a log entry.
Test data: Notification containing a log reference
Test Step:
1. Open notifications.
2. Tap the log-related item.
Expected Result: The app opens the correct logbook or log detail screen.
Actual Result: Pending execution
Test Result: Not Run

### TC-NOTIF-06
Test Case ID: TC-NOTIF-06
TestCase Title: Read Another User's Notification
Descrption: Verify that a user cannot update another user's notification.
Precondition: Two users exist and the target notification belongs to another user.
Test data: Foreign notification ID
Test Step:
1. Log in as User B.
2. Attempt to mark User A's notification as read.
Expected Result: The action is denied and the target notification remains unchanged.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 4 - INTERNSHIP PROFILE MANAGEMENT

### TC-PROF-01
Test Case ID: TC-PROF-01
TestCase Title: Load Supervisor List
Descrption: Verify that the student can retrieve valid supervisors.
Precondition: At least one supervisor account exists.
Test data: None
Test Step:
1. Log in as Student.
2. Open internship profile.
3. Load supervisor options.
Expected Result: Only users with supervisor role appear in the list.
Actual Result: Pending execution
Test Result: Not Run

### TC-PROF-02
Test Case ID: TC-PROF-02
TestCase Title: Create Internship Profile Successfully
Descrption: Verify that a student can create an internship profile with complete valid data.
Precondition: Student has no internship profile yet.
Test data: Company `Acme Corp`; Address `Tacloban City`; Required Hours `486`; Start `2026-06-01`; End `2026-09-30`; Valid supervisor ID
Test Step:
1. Open internship profile form.
2. Fill all required fields.
3. Submit the form.
Expected Result: The profile is created successfully and visible on reload.
Actual Result: Pending execution
Test Result: Not Run

### TC-PROF-03
Test Case ID: TC-PROF-03
TestCase Title: Create Internship Profile with Missing Fields
Descrption: Verify that profile creation fails when required fields are missing.
Precondition: Student is on the internship profile form.
Test data: Blank company name; blank start date
Test Step:
1. Leave one or more required fields blank.
2. Submit the form.
Expected Result: Validation errors are shown and the profile is not created.
Actual Result: Pending execution
Test Result: Not Run

### TC-PROF-04
Test Case ID: TC-PROF-04
TestCase Title: Create Internship Profile with Invalid Supervisor
Descrption: Verify that a non-supervisor account cannot be assigned as supervisor.
Precondition: A non-supervisor user exists.
Test data: Adviser ID or Student ID used as supervisor
Test Step:
1. Open internship profile form.
2. Enter valid internship data.
3. Select an invalid supervisor ID.
4. Submit.
Expected Result: The request fails validation and the profile is not saved.
Actual Result: Pending execution
Test Result: Not Run

### TC-PROF-05
Test Case ID: TC-PROF-05
TestCase Title: Update Internship Profile Successfully
Descrption: Verify that a student can update an existing profile.
Precondition: Student already has an internship profile.
Test data: Updated company `Acme Revised Corp`; Required Hours `600`
Test Step:
1. Open the existing profile.
2. Change one or more fields.
3. Save changes.
4. Reload the screen.
Expected Result: The updated values are saved and displayed.
Actual Result: Pending execution
Test Result: Not Run

### TC-PROF-06
Test Case ID: TC-PROF-06
TestCase Title: Update Internship Profile with Invalid Date Range
Descrption: Verify that profile update fails when end date is earlier than start date.
Precondition: Student already has an internship profile.
Test data: Start `2026-09-30`; End `2026-06-01`
Test Step:
1. Open profile edit.
2. Enter an invalid date range.
3. Save changes.
Expected Result: The update is rejected and the invalid dates are not saved.
Actual Result: Pending execution
Test Result: Not Run

### TC-PROF-07
Test Case ID: TC-PROF-07
TestCase Title: Student Without Login Accesses Internship Profile
Descrption: Verify that unauthenticated users cannot access the internship profile screen or API.
Precondition: User is logged out.
Test data: Internship profile route
Test Step:
1. Try to open the internship profile screen or endpoint while logged out.
Expected Result: The user is redirected to login or receives an unauthenticated response.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 5 - DAILY TIME RECORD

### TC-DTR-01
Test Case ID: TC-DTR-01
TestCase Title: View Initial DTR State
Descrption: Verify that the DTR screen shows the correct initial state when no record exists.
Precondition: No DTR exists for the current day.
Test data: None
Test Step:
1. Log in as Student.
2. Open the DTR screen.
Expected Result: `Not Started` state is shown and `Time In` is available.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-02
Test Case ID: TC-DTR-02
TestCase Title: Successful Time In
Descrption: Verify that a student can record `Time In` and create today's DTR record.
Precondition: No DTR exists yet for today.
Test data: Current system date and time
Test Step:
1. Open the DTR screen.
2. Tap `Time In`.
Expected Result: The system creates today's DTR record, saves `time_in_at` and `am_time_in_at`, sets the status to `WORKING`, shows `Working` as the current state label, and sets the next action to `LUNCH_OUT`.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-03
Test Case ID: TC-DTR-03
TestCase Title: Successful Lunch Out
Descrption: Verify that the student can record `Lunch Out` after `Time In`.
Precondition: The student has already recorded time in.
Test data: Current date and time
Test Step:
1. Tap `Lunch Out`.
Expected Result: The system saves `lunch_out_at` and `am_time_out_at`, computes `first_work_minutes` and `total_work_minutes` for the morning session, changes the status to `ON_BREAK`, shows `On Break` as the current state label, and sets the next action to `LUNCH_IN`.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-04
Test Case ID: TC-DTR-04
TestCase Title: Successful Lunch In
Descrption: Verify that the student can record `Lunch In` after `Lunch Out`.
Precondition: The student is currently on break.
Test data: Current date and time
Test Step:
1. Tap `Lunch In`.
Expected Result: The system saves `lunch_in_at` and `pm_time_in_at`, changes the status back to `WORKING`, shows `Working` as the current state label, and sets the next action to `TIME_OUT`.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-05
Test Case ID: TC-DTR-05
TestCase Title: Successful Time Out
Descrption: Verify that the student can record `Time Out` and complete the whole DTR cycle.
Precondition: The student already recorded `Time In`, `Lunch Out`, and `Lunch In`.
Test data: Current date and time
Test Step:
1. Tap `Time Out`.
2. Refresh the DTR screen.
Expected Result: The system saves `time_out_at` and `pm_time_out_at`, computes `second_work_minutes` and final `total_work_minutes`, changes the status to `COMPLETED`, shows `Completed` as the current state label, and clears the next action.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-06
Test Case ID: TC-DTR-06
TestCase Title: Lunch Out Before Time In
Descrption: Verify that `Lunch Out` is rejected if `Time In` has not been recorded first.
Precondition: No time in exists for today.
Test data: Attempt `Lunch Out`
Test Step:
1. Try to perform `Lunch Out`.
Expected Result: The request is rejected with a conflict response and the message `Time In must be recorded before Lunch Out.`
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-07
Test Case ID: TC-DTR-07
TestCase Title: Lunch In Before Lunch Out
Descrption: Verify that `Lunch In` is rejected when `Lunch Out` has not been recorded yet.
Precondition: The student has recorded `Time In` but has not recorded `Lunch Out`.
Test data: Attempt `Lunch In`
Test Step:
1. Try to perform `Lunch In`.
Expected Result: The request is rejected with a conflict response and the message `Lunch Out must be recorded before Lunch In.`
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-08
Test Case ID: TC-DTR-08
TestCase Title: Time Out Before Time In
Descrption: Verify that `Time Out` is rejected when the student has not yet reached the required `Lunch In` step.
Precondition: No DTR action exists yet today.
Test data: Attempt `Time Out`
Test Step:
1. Try to perform `Time Out`.
Expected Result: The request is rejected with a conflict response and the message `Lunch In must be recorded before Time Out.`
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-09
Test Case ID: TC-DTR-09
TestCase Title: Time Out While Still on Lunch Break
Descrption: Verify that `Time Out` is rejected when `Lunch In` has not been recorded yet.
Precondition: Student has recorded `Time In` and `Lunch Out` but not `Lunch In`.
Test data: Attempt `Time Out`
Test Step:
1. Try to perform `Time Out`.
Expected Result: The request is rejected with a conflict response and the message `Lunch In must be recorded before Time Out.` The record remains in `ON_BREAK` state.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-10
Test Case ID: TC-DTR-10
TestCase Title: Monthly DTR Summary Loads
Descrption: Verify that monthly DTR data can be retrieved and displayed.
Precondition: DTR records exist for the selected month.
Test data: Current month with records
Test Step:
1. Open monthly DTR summary.
2. Load the target month.
Expected Result: DTR entries and totals for the month are displayed correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-11
Test Case ID: TC-DTR-11
TestCase Title: Monthly DTR Summary with No Records
Descrption: Verify that the system handles a month with no DTR records.
Precondition: The selected month has no DTR entries.
Test data: Month with zero records
Test Step:
1. Open monthly DTR summary.
2. Select a month with no entries.
Expected Result: The system shows an empty state and no computation error occurs.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-12
Test Case ID: TC-DTR-12
TestCase Title: Export Student DTR to PDF
Descrption: Verify that the student can export DTR to PDF.
Precondition: DTR records exist for the target period.
Test data: Valid month
Test Step:
1. Open the DTR module.
2. Choose `Export PDF`.
Expected Result: A PDF file is generated or downloaded successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-13
Test Case ID: TC-DTR-13
TestCase Title: Export Student DTR to Excel
Descrption: Verify that the student can export DTR to Excel.
Precondition: DTR records exist for the target period.
Test data: Valid month
Test Step:
1. Open the DTR module.
2. Choose `Export Excel`.
Expected Result: An Excel file is generated or downloaded successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-DTR-14
Test Case ID: TC-DTR-14
TestCase Title: Export DTR Without Records
Descrption: Verify the system behavior when the user exports DTR for a period with no records.
Precondition: Selected month has no DTR entries.
Test data: Month with zero records
Test Step:
1. Open export options.
2. Export DTR for an empty month.
Expected Result: The system either generates an empty report correctly or shows a clear no data message.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 6 - STUDENT LOGBOOK AND ATTACHMENTS

### TC-LOG-01
Test Case ID: TC-LOG-01
TestCase Title: View Student Log List
Descrption: Verify that the student can see their own logs.
Precondition: Student has existing log entries.
Test data: Student-owned logs
Test Step:
1. Log in as Student.
2. Open the logbook screen.
Expected Result: Only the student's own logs are displayed.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-02
Test Case ID: TC-LOG-02
TestCase Title: View Empty Logbook
Descrption: Verify that the app handles a student with no logs.
Precondition: Student has no log entries yet.
Test data: Empty log list
Test Step:
1. Log in as a student with no logs.
2. Open the logbook.
Expected Result: An empty state is shown without errors.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-03
Test Case ID: TC-LOG-03
TestCase Title: Submit New Log Successfully
Descrption: Verify that the student can create a new valid log entry.
Precondition: Student has an internship profile.
Test data: Date `2026-05-20`; Time In `08:00`; Time Out `17:00`; Hours `8`; Narrative `Performed QA testing tasks`
Test Step:
1. Open log submission.
2. Enter complete valid data.
3. Submit.
Expected Result: The log is saved successfully and appears in the logbook list.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-04
Test Case ID: TC-LOG-04
TestCase Title: Submit Log with Missing Required Fields
Descrption: Verify that log submission fails when required fields are incomplete.
Precondition: Student is on the log submission form.
Test data: Blank narrative; missing hours
Test Step:
1. Leave one or more required fields blank.
2. Submit the form.
Expected Result: Validation messages are shown and the log is not saved.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-05
Test Case ID: TC-LOG-05
TestCase Title: Submit Log with Invalid Time Range
Descrption: Verify that a log cannot be submitted when time out is earlier than time in.
Precondition: Student is on the log submission form.
Test data: Time In `17:00`; Time Out `08:00`
Test Step:
1. Enter an invalid time range.
2. Submit the log.
Expected Result: The log is rejected and the invalid time range is not saved.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-06
Test Case ID: TC-LOG-06
TestCase Title: View Log Detail
Descrption: Verify that the student can open and view log details.
Precondition: Student has at least one log.
Test data: Existing log ID
Test Step:
1. Open the logbook.
2. Select a log entry.
Expected Result: The selected log detail page opens with complete log information.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-07
Test Case ID: TC-LOG-07
TestCase Title: Edit Pending Log Successfully
Descrption: Verify that the student can edit a log that is still editable.
Precondition: Student owns an editable log.
Test data: Updated narrative `Performed testing and documentation`
Test Step:
1. Open a pending log.
2. Tap edit.
3. Update one or more fields.
4. Save.
Expected Result: The changes are saved and visible in the log detail.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-08
Test Case ID: TC-LOG-08
TestCase Title: Edit Log with Invalid Data
Descrption: Verify that log editing fails when invalid values are entered.
Precondition: Student owns an editable log.
Test data: Blank narrative or invalid hours
Test Step:
1. Open an editable log.
2. Enter invalid data.
3. Save changes.
Expected Result: Validation appears and the invalid update is not saved.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-09
Test Case ID: TC-LOG-09
TestCase Title: Upload Valid JPG Attachment
Descrption: Verify that the student can upload a valid JPG proof attachment.
Precondition: Student owns a log that allows proof upload.
Test data: File `proof.jpg`
Test Step:
1. Open log detail.
2. Choose `Upload Attachment`.
3. Select `proof.jpg`.
4. Submit.
Expected Result: The JPG attachment uploads successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-10
Test Case ID: TC-LOG-10
TestCase Title: Upload Valid PDF Attachment
Descrption: Verify that the student can upload a valid PDF proof attachment.
Precondition: Student owns a log that allows proof upload.
Test data: File `proof.pdf`
Test Step:
1. Open log detail.
2. Choose `Upload Attachment`.
3. Select `proof.pdf`.
4. Submit.
Expected Result: The PDF attachment uploads successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-11
Test Case ID: TC-LOG-11
TestCase Title: Upload Unsupported Attachment Type
Descrption: Verify that unsupported file types are rejected during attachment upload.
Precondition: Student owns a log that allows proof upload.
Test data: File `proof.exe`
Test Step:
1. Open log detail.
2. Attempt to upload an unsupported file.
Expected Result: The upload is rejected and an error is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-12
Test Case ID: TC-LOG-12
TestCase Title: Upload Duplicate Proof Attachment
Descrption: Verify that the system prevents adding a second proof attachment when one already exists.
Precondition: The selected log already has one proof attachment.
Test data: Another valid file `proof2.jpg`
Test Step:
1. Open a log with an existing proof.
2. Attempt to upload a second proof file.
Expected Result: The second upload is blocked.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-13
Test Case ID: TC-LOG-13
TestCase Title: Download Owned Attachment
Descrption: Verify that the student can download their own attachment.
Precondition: Student owns a log with an attachment.
Test data: Valid owned attachment ID
Test Step:
1. Open log detail.
2. Tap the attachment to download or open it.
Expected Result: The attachment downloads or opens successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-14
Test Case ID: TC-LOG-14
TestCase Title: View Another Student's Log
Descrption: Verify that a student cannot access another student's log entry.
Precondition: Two student accounts exist with different logs.
Test data: Foreign log ID
Test Step:
1. Log in as Student B.
2. Attempt to open Student A's log.
Expected Result: Access is denied and other student data is not exposed.
Actual Result: Pending execution
Test Result: Not Run

### TC-LOG-15
Test Case ID: TC-LOG-15
TestCase Title: Download Another Student's Attachment
Descrption: Verify that a student cannot download another student's proof attachment.
Precondition: Another student has a log attachment.
Test data: Foreign attachment ID
Test Step:
1. Log in as Student B.
2. Attempt to access Student A's attachment.
Expected Result: Access is denied and the file is not served.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 7 - EDIT REQUEST WORKFLOW

### TC-EDIT-01
Test Case ID: TC-EDIT-01
TestCase Title: Submit Log Edit Request Successfully
Descrption: Verify that a student can submit a valid log edit request.
Precondition: Student owns a log eligible for edit request.
Test data: Reason `Need to correct logged hours`
Test Step:
1. Open the target log.
2. Tap `Request Edit`.
3. Enter a reason.
4. Submit.
Expected Result: The edit request is saved successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-02
Test Case ID: TC-EDIT-02
TestCase Title: Submit Log Edit Request Without Reason
Descrption: Verify that a log edit request is blocked when required justification is missing.
Precondition: Student owns an eligible log.
Test data: Blank reason
Test Step:
1. Open `Request Edit`.
2. Leave the reason blank.
3. Submit.
Expected Result: Validation is shown and the request is not created.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-03
Test Case ID: TC-EDIT-03
TestCase Title: Submit DTR Edit Request Successfully
Descrption: Verify that a student can request correction for DTR data.
Precondition: Student has an existing DTR record.
Test data: Reason `Forgot to time out on 2026-05-20`
Test Step:
1. Open the DTR correction flow.
2. Enter a reason.
3. Submit.
Expected Result: The DTR edit request is saved successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-04
Test Case ID: TC-EDIT-04
TestCase Title: Submit DTR Edit Request Without Reason
Descrption: Verify that a DTR edit request fails without a valid reason.
Precondition: Student has an editable DTR-related request path.
Test data: Blank reason
Test Step:
1. Open the DTR edit request flow.
2. Leave the reason blank.
3. Submit.
Expected Result: The request is rejected and a validation message appears.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-05
Test Case ID: TC-EDIT-05
TestCase Title: Admin View Pending Edit Requests
Descrption: Verify that admin users can load pending edit requests.
Precondition: At least one edit request exists.
Test data: Pending edit request records
Test Step:
1. Log in as Admin.
2. Open edit request management.
Expected Result: Pending requests are listed correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-06
Test Case ID: TC-EDIT-06
TestCase Title: Approve Edit Request
Descrption: Verify that admin can approve a pending edit request.
Precondition: A pending edit request exists.
Test data: Pending request ID
Test Step:
1. Open edit request management.
2. Select a pending request.
3. Approve it.
Expected Result: The request status changes to approved.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-07
Test Case ID: TC-EDIT-07
TestCase Title: Reject Edit Request
Descrption: Verify that admin can reject a pending edit request.
Precondition: A pending edit request exists.
Test data: Pending request ID
Test Step:
1. Open edit request management.
2. Select a pending request.
3. Reject it.
Expected Result: The request status changes to rejected.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-08
Test Case ID: TC-EDIT-08
TestCase Title: Approve Already Finalized Edit Request
Descrption: Verify that an already approved or rejected request cannot be processed again.
Precondition: The request is already finalized.
Test data: Finalized request ID
Test Step:
1. Attempt to approve or reject the same request again.
Expected Result: The system blocks the repeated action and preserves the final status.
Actual Result: Pending execution
Test Result: Not Run

### TC-EDIT-09
Test Case ID: TC-EDIT-09
TestCase Title: Non-Admin Access to Edit Request Management
Descrption: Verify that students, supervisors, and advisers cannot access admin edit request controls.
Precondition: Non-admin account is logged in.
Test data: Admin edit request route or endpoint
Test Step:
1. Log in as a non-admin user.
2. Attempt to access edit request management.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 8 - REPORTS AND EXPORTS

### TC-REP-01
Test Case ID: TC-REP-01
TestCase Title: Student View Own Report
Descrption: Verify that a student can load their own report data.
Precondition: Student has internship-related data.
Test data: Student account with logs or DTR records
Test Step:
1. Log in as Student.
2. Open the report page.
Expected Result: The student's report is displayed successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-02
Test Case ID: TC-REP-02
TestCase Title: Student Report with No Available Data
Descrption: Verify that the report page handles a student with little or no reportable data.
Precondition: Student has no completed logs or DTR records.
Test data: Student account with minimal data
Test Step:
1. Open the report page.
Expected Result: The page shows a safe empty or zero state without crashing.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-03
Test Case ID: TC-REP-03
TestCase Title: Supervisor View Assigned Student Report
Descrption: Verify that a supervisor can view the report of an assigned student.
Precondition: Supervisor has an assigned student.
Test data: Assigned student ID
Test Step:
1. Log in as Supervisor.
2. Open intern list.
3. Select an assigned student.
4. Open report.
Expected Result: The report is displayed for the chosen assigned student.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-04
Test Case ID: TC-REP-04
TestCase Title: Supervisor View Unassigned Student Report
Descrption: Verify that a supervisor cannot view a report for an unassigned student.
Precondition: Another student exists outside the supervisor assignment.
Test data: Unassigned student ID
Test Step:
1. Log in as Supervisor.
2. Attempt to open a report for an unassigned student.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-05
Test Case ID: TC-REP-05
TestCase Title: Adviser View Assigned Student Report
Descrption: Verify that an adviser can view the report of an assigned student.
Precondition: Adviser has an assigned student.
Test data: Assigned student ID
Test Step:
1. Log in as Adviser.
2. Open intern list.
3. Select an assigned student.
4. Open report.
Expected Result: The selected student's report is displayed.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-06
Test Case ID: TC-REP-06
TestCase Title: Adviser View Unassigned Student Report
Descrption: Verify that an adviser cannot access reports for unassigned students.
Precondition: An unassigned or differently assigned student exists.
Test data: Unassigned student ID
Test Step:
1. Log in as Adviser.
2. Attempt to open the student's report.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-07
Test Case ID: TC-REP-07
TestCase Title: Supervisor Export Assigned Student DTR to PDF
Descrption: Verify that a supervisor can export PDF for an assigned student's DTR.
Precondition: Assigned student has DTR records.
Test data: Assigned student ID; target month
Test Step:
1. Open assigned student details.
2. Choose PDF export.
Expected Result: The export succeeds and the file is generated.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-08
Test Case ID: TC-REP-08
TestCase Title: Supervisor Export Unassigned Student DTR
Descrption: Verify that a supervisor cannot export DTR for an unassigned student.
Precondition: An unassigned student exists.
Test data: Unassigned student ID
Test Step:
1. Attempt to export the unassigned student's DTR.
Expected Result: Access is denied and no file is generated.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-09
Test Case ID: TC-REP-09
TestCase Title: Adviser Export Assigned Student DTR to Excel
Descrption: Verify that an adviser can export an assigned student's DTR to Excel.
Precondition: Assigned student has DTR data.
Test data: Assigned student ID; target month
Test Step:
1. Open the assigned student's details.
2. Choose Excel export.
Expected Result: Excel export succeeds.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-10
Test Case ID: TC-REP-10
TestCase Title: Adviser Export Unassigned Student DTR
Descrption: Verify that an adviser cannot export another student's DTR when not assigned.
Precondition: An unassigned student exists.
Test data: Unassigned student ID
Test Step:
1. Attempt to export the student's DTR.
Expected Result: Access is denied and no file is returned.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-11
Test Case ID: TC-REP-11
TestCase Title: Admin Export Student DTR to PDF
Descrption: Verify that an admin can export student DTR when needed.
Precondition: Student with DTR records exists.
Test data: Student ID; target month
Test Step:
1. Log in as Admin.
2. Open the relevant student record or export function.
3. Export to PDF.
Expected Result: The PDF file is generated successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-REP-12
Test Case ID: TC-REP-12
TestCase Title: Export Report with No Matching Data
Descrption: Verify that export handles empty datasets safely.
Precondition: The selected student or month has no available data.
Test data: Empty month or empty student record
Test Step:
1. Trigger export for a period with no data.
Expected Result: The system returns a clear no data response or a valid empty report.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 9 - SUPERVISOR DASHBOARD AND INTERN MONITORING

### TC-SUPD-01
Test Case ID: TC-SUPD-01
TestCase Title: View Supervisor Dashboard
Descrption: Verify that a supervisor can load dashboard summary data.
Precondition: Supervisor is logged in.
Test data: Supervisor with assigned interns
Test Step:
1. Log in as Supervisor.
2. Open the dashboard.
Expected Result: Dashboard metrics and pending counts are displayed.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-02
Test Case ID: TC-SUPD-02
TestCase Title: View Assigned Intern List
Descrption: Verify that a supervisor can view only their assigned interns.
Precondition: Supervisor has assigned interns.
Test data: Assigned and unassigned students
Test Step:
1. Open the intern list.
Expected Result: Only assigned interns are listed.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-03
Test Case ID: TC-SUPD-03
TestCase Title: Assigned Intern List with No Interns
Descrption: Verify that the intern list handles a supervisor with no assigned interns.
Precondition: Supervisor has no assigned students.
Test data: Empty assignment set
Test Step:
1. Open the intern list.
Expected Result: The system shows an empty state without error.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-04
Test Case ID: TC-SUPD-04
TestCase Title: View Assigned Intern Detail
Descrption: Verify that a supervisor can open details for an assigned intern.
Precondition: Supervisor has at least one assigned student.
Test data: Assigned student ID
Test Step:
1. Open intern list.
2. Select an assigned student.
Expected Result: The selected intern detail page loads correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-05
Test Case ID: TC-SUPD-05
TestCase Title: View Unassigned Intern Detail
Descrption: Verify that a supervisor cannot access details for an unassigned student.
Precondition: Another student exists outside the supervisor's assignment.
Test data: Unassigned student ID
Test Step:
1. Attempt to open the unassigned student's details.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-06
Test Case ID: TC-SUPD-06
TestCase Title: View Assigned Intern Progress
Descrption: Verify that a supervisor can load progress data for an assigned intern.
Precondition: Assigned student has progress records.
Test data: Assigned student ID
Test Step:
1. Open an assigned student's details.
2. View the progress section.
Expected Result: Progress information is displayed correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-07
Test Case ID: TC-SUPD-07
TestCase Title: View Progress for Student with No Records
Descrption: Verify that progress view handles students with no progress records yet.
Precondition: Assigned student has no logs or DTR records.
Test data: Assigned student ID with no progress data
Test Step:
1. Open the student's progress view.
Expected Result: The system shows a safe empty or zero-progress state.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPD-08
Test Case ID: TC-SUPD-08
TestCase Title: Non-Supervisor Access to Supervisor Dashboard
Descrption: Verify that non-supervisor users cannot open supervisor-only dashboard screens.
Precondition: Student, Adviser, or Admin is logged in.
Test data: Supervisor dashboard route
Test Step:
1. Log in as a non-supervisor.
2. Attempt to open the supervisor dashboard.
Expected Result: The app redirects the user away from the supervisor dashboard.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 10 - SUPERVISOR LOG REVIEW

### TC-SUPL-01
Test Case ID: TC-SUPL-01
TestCase Title: View Pending Log Queue
Descrption: Verify that a supervisor can view pending logs for assigned students.
Precondition: Assigned students have pending logs.
Test data: Pending log queue
Test Step:
1. Log in as Supervisor.
2. Open the log review queue.
Expected Result: Pending logs for assigned interns are displayed.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-02
Test Case ID: TC-SUPL-02
TestCase Title: Empty Pending Log Queue
Descrption: Verify that the queue handles a supervisor with no pending logs.
Precondition: No pending logs exist for the supervisor.
Test data: Empty review queue
Test Step:
1. Open the log review queue.
Expected Result: An empty state is shown with no errors.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-03
Test Case ID: TC-SUPL-03
TestCase Title: Open Pending Log Detail
Descrption: Verify that a supervisor can view the detail of a pending log.
Precondition: At least one pending log exists for an assigned student.
Test data: Pending log ID
Test Step:
1. Select a pending log from the queue.
Expected Result: The full log detail page opens with related information.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-04
Test Case ID: TC-SUPL-04
TestCase Title: Approve Pending Log
Descrption: Verify that a supervisor can approve a pending log.
Precondition: Pending log exists for an assigned student.
Test data: Pending log ID
Test Step:
1. Open the pending log.
2. Tap `Approve`.
3. Confirm if prompted.
Expected Result: The log status changes to approved.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-05
Test Case ID: TC-SUPL-05
TestCase Title: Reject Pending Log
Descrption: Verify that a supervisor can reject a pending log.
Precondition: Pending log exists for an assigned student.
Test data: Pending log ID
Test Step:
1. Open the pending log.
2. Tap `Reject`.
3. Confirm if prompted.
Expected Result: The log status changes to rejected.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-06
Test Case ID: TC-SUPL-06
TestCase Title: Approve Already Finalized Log
Descrption: Verify that a finalized log cannot be approved again.
Precondition: The log has already been approved or rejected.
Test data: Finalized log ID
Test Step:
1. Attempt to approve the finalized log again.
Expected Result: The repeated review action is blocked.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-07
Test Case ID: TC-SUPL-07
TestCase Title: Reject Already Finalized Log
Descrption: Verify that a finalized log cannot be rejected again.
Precondition: The log has already been approved or rejected.
Test data: Finalized log ID
Test Step:
1. Attempt to reject the finalized log again.
Expected Result: The repeated review action is blocked.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-08
Test Case ID: TC-SUPL-08
TestCase Title: Review Unassigned Student Log
Descrption: Verify that a supervisor cannot review logs for students who are not assigned to them.
Precondition: Another student's pending log exists outside the assignment.
Test data: Unassigned student's log ID
Test Step:
1. Attempt to open or review the foreign log.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-09
Test Case ID: TC-SUPL-09
TestCase Title: Download Attachment During Review
Descrption: Verify that the supervisor can download an attachment from an assigned student's log.
Precondition: Assigned student's log contains an attachment.
Test data: Valid attachment ID
Test Step:
1. Open log detail.
2. Download the attachment.
Expected Result: The file downloads or opens successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-SUPL-10
Test Case ID: TC-SUPL-10
TestCase Title: Download Attachment from Unassigned Student Log
Descrption: Verify that a supervisor cannot access an attachment from an unassigned student's log.
Precondition: Another student's log attachment exists.
Test data: Foreign attachment ID
Test Step:
1. Attempt to download the attachment.
Expected Result: Access is denied and the file is not served.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 11 - ADVISER MONITORING

### TC-ADV-01
Test Case ID: TC-ADV-01
TestCase Title: View Adviser Intern List
Descrption: Verify that an adviser can view assigned students.
Precondition: Adviser has assigned students.
Test data: Adviser assignment data
Test Step:
1. Log in as Adviser.
2. Open the intern list.
Expected Result: Only assigned students are displayed.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-02
Test Case ID: TC-ADV-02
TestCase Title: Adviser Intern List with No Assignments
Descrption: Verify that the adviser intern list handles zero assignments.
Precondition: Adviser has no assigned students.
Test data: Empty assignment list
Test Step:
1. Open the intern list.
Expected Result: An empty state is shown correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-03
Test Case ID: TC-ADV-03
TestCase Title: Open Assigned Intern Detail
Descrption: Verify that an adviser can open an assigned student's details.
Precondition: Adviser has at least one assigned student.
Test data: Assigned student ID
Test Step:
1. Open the adviser intern list.
2. Select an assigned student.
Expected Result: The student's details are displayed correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-04
Test Case ID: TC-ADV-04
TestCase Title: Open Unassigned Intern Detail
Descrption: Verify that an adviser cannot access an unassigned student's details.
Precondition: Another student exists outside the adviser's assignment.
Test data: Unassigned student ID
Test Step:
1. Attempt to open the student detail.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-05
Test Case ID: TC-ADV-05
TestCase Title: View Assigned Student Log
Descrption: Verify that an adviser can open a log from an assigned student.
Precondition: Assigned student has at least one log.
Test data: Assigned student's log ID
Test Step:
1. Open assigned student details.
2. Select a log entry.
Expected Result: The adviser can view the log details.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-06
Test Case ID: TC-ADV-06
TestCase Title: View Unassigned Student Log
Descrption: Verify that an adviser cannot access log details from an unassigned student.
Precondition: Another student's log exists outside adviser assignment.
Test data: Foreign log ID
Test Step:
1. Attempt to open the foreign log.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-07
Test Case ID: TC-ADV-07
TestCase Title: Download Assigned Student Attachment
Descrption: Verify that an adviser can download proof attachments from an assigned student's log.
Precondition: Assigned student's log has an attachment.
Test data: Valid attachment ID
Test Step:
1. Open the log detail.
2. Download the attachment.
Expected Result: The attachment downloads successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-08
Test Case ID: TC-ADV-08
TestCase Title: Download Unassigned Student Attachment
Descrption: Verify that an adviser cannot download attachments from an unassigned student's log.
Precondition: Another student's attachment exists outside the adviser assignment.
Test data: Foreign attachment ID
Test Step:
1. Attempt to download the foreign attachment.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADV-09
Test Case ID: TC-ADV-09
TestCase Title: Non-Adviser User Opens Adviser Module
Descrption: Verify that non-adviser users cannot access adviser-only intern monitoring.
Precondition: Student, Supervisor, or Admin account is logged in.
Test data: Adviser module route
Test Step:
1. Log in as a non-adviser role.
2. Attempt to open adviser intern monitoring.
Expected Result: Access is denied or the user is redirected away.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 12 - ADMIN DASHBOARD, USER MANAGEMENT, AND ASSIGNMENTS

### TC-ADMIN-01
Test Case ID: TC-ADMIN-01
TestCase Title: View Admin Dashboard Metrics
Descrption: Verify that admin can view overall dashboard metrics.
Precondition: Admin is logged in.
Test data: Existing users, students, and logs
Test Step:
1. Log in as Admin.
2. Open admin dashboard.
Expected Result: Dashboard metrics load correctly.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-02
Test Case ID: TC-ADMIN-02
TestCase Title: View Student Listing
Descrption: Verify that admin can load the student list.
Precondition: Student records exist.
Test data: Multiple student records
Test Step:
1. Open admin student listing.
Expected Result: Student records are displayed successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-03
Test Case ID: TC-ADMIN-03
TestCase Title: View User Management List
Descrption: Verify that admin can load the user management page.
Precondition: User records exist for multiple roles.
Test data: Admin, Student, Supervisor, Adviser records
Test Step:
1. Open user management.
Expected Result: All users are displayed with correct role information.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-04
Test Case ID: TC-ADMIN-04
TestCase Title: Create User Successfully
Descrption: Verify that admin can create a new user with valid details.
Precondition: The target email is unused.
Test data: Name `Maria Supervisor`; Email `maria.supervisor@example.com`; Role `Supervisor`; Password `Password123`
Test Step:
1. Open `Add User`.
2. Enter valid data.
3. Save the user.
Expected Result: The new user is created and appears in the list.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-05
Test Case ID: TC-ADMIN-05
TestCase Title: Create User with Duplicate Email
Descrption: Verify that admin cannot create a user using an existing email.
Precondition: A user already exists with the target email.
Test data: Email `maria.supervisor@example.com`
Test Step:
1. Open `Add User`.
2. Enter a duplicate email.
3. Save.
Expected Result: User creation is rejected and email uniqueness validation is shown.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-06
Test Case ID: TC-ADMIN-06
TestCase Title: Create User with Missing Required Data
Descrption: Verify that admin cannot create a user when required fields are empty.
Precondition: Admin is on the add user form.
Test data: Blank email or blank password
Test Step:
1. Leave one or more required fields blank.
2. Save the form.
Expected Result: Validation messages are shown and the user is not created.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-07
Test Case ID: TC-ADMIN-07
TestCase Title: Delete User Successfully
Descrption: Verify that admin can delete a deletable user account.
Precondition: A deletable user exists.
Test data: Target user ID
Test Step:
1. Open user management.
2. Choose a user.
3. Delete and confirm.
Expected Result: The selected user is removed from the list.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-08
Test Case ID: TC-ADMIN-08
TestCase Title: Delete Nonexistent User
Descrption: Verify that the system handles deletion of an invalid or nonexistent user ID safely.
Precondition: Admin is authenticated.
Test data: Invalid user ID
Test Step:
1. Attempt to delete a nonexistent user.
Expected Result: The request fails gracefully and no unrelated records are affected.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-09
Test Case ID: TC-ADMIN-09
TestCase Title: Assign Adviser to Student Successfully
Descrption: Verify that admin can assign an adviser to a student.
Precondition: Student and adviser records exist.
Test data: Student ID; Adviser ID
Test Step:
1. Open student assignment management.
2. Select a student.
3. Assign an adviser.
4. Save.
Expected Result: Adviser assignment is saved successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-10
Test Case ID: TC-ADMIN-10
TestCase Title: Assign Supervisor to Student Successfully
Descrption: Verify that admin can assign a supervisor to a student.
Precondition: Student and supervisor records exist.
Test data: Student ID; Supervisor ID
Test Step:
1. Open assignment management.
2. Select a student.
3. Assign a supervisor.
4. Save.
Expected Result: Supervisor assignment is saved successfully.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-11
Test Case ID: TC-ADMIN-11
TestCase Title: Assign Invalid Adviser Role to Student
Descrption: Verify that admin cannot assign a user who is not an adviser into the adviser slot.
Precondition: A non-adviser user exists.
Test data: Student ID; Student or Supervisor ID as adviser
Test Step:
1. Attempt to assign an invalid user as adviser.
2. Save changes.
Expected Result: The system rejects the assignment.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-12
Test Case ID: TC-ADMIN-12
TestCase Title: Assign Invalid Supervisor Role to Student
Descrption: Verify that admin cannot assign a non-supervisor user as supervisor.
Precondition: A non-supervisor user exists.
Test data: Student ID; Adviser or Student ID as supervisor
Test Step:
1. Attempt to assign an invalid user as supervisor.
2. Save changes.
Expected Result: The assignment is rejected.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-13
Test Case ID: TC-ADMIN-13
TestCase Title: View Current Adviser Assignment
Descrption: Verify that admin can retrieve a student's current adviser assignment.
Precondition: Student already has an adviser assigned.
Test data: Student ID
Test Step:
1. Open the student's assignment record.
2. Load adviser information.
Expected Result: The correct adviser is displayed.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-14
Test Case ID: TC-ADMIN-14
TestCase Title: View Current Supervisor Assignment
Descrption: Verify that admin can retrieve a student's current supervisor assignment.
Precondition: Student already has a supervisor assigned.
Test data: Student ID
Test Step:
1. Open the student's assignment record.
2. Load supervisor information.
Expected Result: The correct supervisor is displayed.
Actual Result: Pending execution
Test Result: Not Run

### TC-ADMIN-15
Test Case ID: TC-ADMIN-15
TestCase Title: Non-Admin Access to Admin Dashboard
Descrption: Verify that non-admin users cannot open admin-only pages or endpoints.
Precondition: Student, Supervisor, or Adviser account is logged in.
Test data: Admin dashboard route or endpoint
Test Step:
1. Log in as a non-admin role.
2. Attempt to access admin dashboard or admin management pages.
Expected Result: Access is denied or redirected away.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 13 - ROLE-BASED ACCESS CONTROL AND ROUTE GUARDS

### TC-RBAC-01
Test Case ID: TC-RBAC-01
TestCase Title: Student Cannot Access Supervisor Endpoint
Descrption: Verify that a student account cannot call supervisor-only endpoints.
Precondition: Student is logged in.
Test data: `GET /api/v1/supervisor/logs`
Test Step:
1. Authenticate as Student.
2. Attempt to access the supervisor endpoint.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

### TC-RBAC-02
Test Case ID: TC-RBAC-02
TestCase Title: Student Cannot Access Admin Endpoint
Descrption: Verify that a student account cannot call admin-only endpoints.
Precondition: Student is logged in.
Test data: `GET /api/v1/admin/dashboard`
Test Step:
1. Authenticate as Student.
2. Attempt to open the admin dashboard endpoint.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

### TC-RBAC-03
Test Case ID: TC-RBAC-03
TestCase Title: Adviser Cannot Create Student Log
Descrption: Verify that an adviser cannot use student-only log submission endpoints.
Precondition: Adviser is logged in.
Test data: `POST /api/v1/student/logs`
Test Step:
1. Authenticate as Adviser.
2. Submit a student log payload.
Expected Result: Access is denied and no log is created.
Actual Result: Pending execution
Test Result: Not Run

### TC-RBAC-04
Test Case ID: TC-RBAC-04
TestCase Title: Supervisor Cannot Access Admin User Management
Descrption: Verify that supervisors cannot access admin user management endpoints.
Precondition: Supervisor is logged in.
Test data: `GET /api/v1/admin/users`
Test Step:
1. Authenticate as Supervisor.
2. Attempt to open admin user management.
Expected Result: Access is denied.
Actual Result: Pending execution
Test Result: Not Run

### TC-RBAC-05
Test Case ID: TC-RBAC-05
TestCase Title: Role Route Guard Redirects Wrong Role
Descrption: Verify that the Flutter role guard redirects users who open another role's route.
Precondition: User is logged in under any role.
Test data: Student opens supervisor dashboard route
Test Step:
1. Log in as Student.
2. Navigate directly to a supervisor or admin route.
Expected Result: The app redirects the user back to the correct dashboard for their role.
Actual Result: Pending execution
Test Result: Not Run

### TC-RBAC-06
Test Case ID: TC-RBAC-06
TestCase Title: Guest Cannot Access Protected Route
Descrption: Verify that unauthenticated users cannot open protected screens.
Precondition: User is logged out.
Test data: Protected route such as `/settings`
Test Step:
1. Open a protected route directly while logged out.
Expected Result: The login screen is shown instead of the protected screen.
Actual Result: Pending execution
Test Result: Not Run

---

## MODULE 14 - API FOUNDATION, SECURITY, AND SYSTEM RESILIENCE

### TC-SEC-01
Test Case ID: TC-SEC-01
TestCase Title: Public Health Endpoint Responds Successfully
Descrption: Verify that the public health endpoint is accessible without login.
Precondition: API server is running.
Test data: `GET /api/v1/health`
Test Step:
1. Send a request to the health endpoint without authentication.
Expected Result: The endpoint responds successfully with API status information.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-02
Test Case ID: TC-SEC-02
TestCase Title: Protected Endpoint Without Token
Descrption: Verify that protected endpoints reject unauthenticated requests.
Precondition: No valid token is attached to the request.
Test data: `GET /api/v1/notifications`
Test Step:
1. Call a protected endpoint without a token.
Expected Result: The request is rejected as unauthenticated.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-03
Test Case ID: TC-SEC-03
TestCase Title: Protected Endpoint with Invalid Token
Descrption: Verify that requests using an invalid token are rejected.
Precondition: An invalid or expired token is available.
Test data: Invalid bearer token
Test Step:
1. Call a protected endpoint using the invalid token.
Expected Result: Access is denied and the user is treated as unauthenticated.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-04
Test Case ID: TC-SEC-04
TestCase Title: Input Sanitization on Text Field
Descrption: Verify that unsafe script-like input is sanitized or rejected.
Precondition: User can submit a text field such as log narrative or profile value.
Test data: `<script>alert('x')</script>`
Test Step:
1. Enter the payload into a supported text field.
2. Submit the form.
3. Reload the saved data if accepted.
Expected Result: Unsafe script content is sanitized or rejected and never rendered as executable code.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-05
Test Case ID: TC-SEC-05
TestCase Title: Rate Limit on Login Attempts
Descrption: Verify that repeated login attempts are throttled when limits are exceeded.
Precondition: Login endpoint is available.
Test data: More than the allowed number of rapid invalid login attempts
Test Step:
1. Repeatedly submit invalid login credentials.
2. Continue until the threshold is exceeded.
Expected Result: The system throttles requests and returns a limit message.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-06
Test Case ID: TC-SEC-06
TestCase Title: Rate Limit on Attachment Upload
Descrption: Verify that repeated attachment uploads are throttled when limits are exceeded.
Precondition: Student owns a log eligible for uploads.
Test data: More than the allowed number of upload attempts in a short time
Test Step:
1. Repeatedly trigger attachment upload requests.
2. Continue beyond the allowed limit.
Expected Result: The endpoint applies throttling and returns a limit response.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-07
Test Case ID: TC-SEC-07
TestCase Title: API Handles Not Found Record Gracefully
Descrption: Verify that requests for nonexistent records return safe not found responses.
Precondition: User is authenticated.
Test data: Nonexistent log ID or user ID
Test Step:
1. Request a record using an invalid ID that does not exist.
Expected Result: The API returns a safe not found response without exposing internal details.
Actual Result: Pending execution
Test Result: Not Run

### TC-SEC-08
Test Case ID: TC-SEC-08
TestCase Title: API Response on Server Error Path
Descrption: Verify that the system returns controlled error behavior when an internal failure occurs.
Precondition: A safe non-production test setup is available to simulate failure.
Test data: Forced backend error scenario
Test Step:
1. Trigger a controlled server-side failure scenario.
2. Observe the client and API behavior.
Expected Result: The system returns a controlled error response and does not expose sensitive stack information to the user.
Actual Result: Pending execution
Test Result: Not Run
