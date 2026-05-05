<?php

namespace Tests\Unit\Services;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\User;
use App\Services\NotificationMailService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class NotificationMailServiceTest extends TestCase
{
    use RefreshDatabase;

    private NotificationMailService $service;

    protected function setUp(): void
    {
        parent::setUp();
        $this->service = new NotificationMailService();
        Queue::fake();
        Mail::fake();
    }

    /**
     * Test that log pending approval email is queued successfully
     */
    public function test_send_log_pending_approval_email_queues_mail(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'PENDING');

        $this->service->sendLogPendingApprovalEmail($log, $supervisor);

        Mail::assertQueued(\App\Mail\LogPendingApproval::class, function ($mail) use ($supervisor) {
            return $mail->hasTo($supervisor->email);
        });
    }

    /**
     * Test that log approved email is queued successfully
     */
    public function test_send_log_approved_email_queues_mail(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'APPROVED');

        $this->service->sendLogApprovedEmail($log, $supervisor->name);

        Mail::assertQueued(\App\Mail\LogApproved::class, function ($mail) use ($student) {
            return $mail->hasTo($student->email);
        });
    }

    /**
     * Test that log rejected email is queued successfully
     */
    public function test_send_log_rejected_email_queues_mail(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'REJECTED');
        $comment = 'Please add more details to the task description.';

        $this->service->sendLogRejectedEmail($log, $supervisor->name, $comment);

        Mail::assertQueued(\App\Mail\LogRejected::class, function ($mail) use ($student, $comment) {
            return $mail->hasTo($student->email) && $mail->comment === $comment;
        });
    }

    /**
     * Test that log rejected email works with null comment
     */
    public function test_send_log_rejected_email_with_null_comment(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'REJECTED');

        $this->service->sendLogRejectedEmail($log, $supervisor->name, null);

        Mail::assertQueued(\App\Mail\LogRejected::class, function ($mail) use ($student) {
            return $mail->hasTo($student->email) && $mail->comment === null;
        });
    }

    /**
     * Test that email is not sent when student is missing
     */
    public function test_send_log_pending_approval_email_handles_missing_student_gracefully(): void
    {
        $supervisor = $this->createSupervisor();
        
        // Create a log entry with no student
        $log = new LogEntry([
            'date' => now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Test task',
            'status' => 'PENDING',
            'internship_profile_id' => null,
        ]);

        // Should not throw exception
        $this->service->sendLogPendingApprovalEmail($log, $supervisor);

        // No email should be queued
        Mail::assertNothingQueued();
    }

    /**
     * Test that log approved email handles missing student gracefully
     */
    public function test_send_log_approved_email_handles_missing_student_gracefully(): void
    {
        $log = new LogEntry([
            'date' => now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Test task',
            'status' => 'APPROVED',
            'internship_profile_id' => null,
        ]);

        // Should not throw exception
        $this->service->sendLogApprovedEmail($log, 'Test Supervisor');

        // No email should be queued
        Mail::assertNothingQueued();
    }

    /**
     * Test that log rejected email handles missing student gracefully
     */
    public function test_send_log_rejected_email_handles_missing_student_gracefully(): void
    {
        $log = new LogEntry([
            'date' => now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Test task',
            'status' => 'REJECTED',
            'internship_profile_id' => null,
        ]);

        // Should not throw exception
        $this->service->sendLogRejectedEmail($log, 'Test Supervisor', 'Please revise');

        // No email should be queued
        Mail::assertNothingQueued();
    }

    /**
     * Test that email subject lines are correct
     */
    public function test_log_pending_approval_email_has_correct_subject(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'PENDING');

        $this->service->sendLogPendingApprovalEmail($log, $supervisor);

        Mail::assertQueued(\App\Mail\LogPendingApproval::class, function ($mail) use ($log) {
            return str_contains($mail->build()->view->data['message']->subject ?? '', $log->date) ||
                   str_contains($mail->subject, $log->date);
        });
    }

    /**
     * Test that multiple emails can be queued without interference
     */
    public function test_multiple_notification_emails_can_be_queued(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        
        $log1 = $this->createLogEntryFor($profile, 'PENDING', now()->toDateString());
        $log2 = $this->createLogEntryFor($profile, 'APPROVED', now()->subDay()->toDateString());

        $this->service->sendLogPendingApprovalEmail($log1, $supervisor);
        $this->service->sendLogApprovedEmail($log2, $supervisor->name);

        Mail::assertQueued(\App\Mail\LogPendingApproval::class);
        Mail::assertQueued(\App\Mail\LogApproved::class);
    }
}
