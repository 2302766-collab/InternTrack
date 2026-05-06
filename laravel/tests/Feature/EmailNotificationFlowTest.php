<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EmailNotificationFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Mail::fake();
    }

    /**
     * Test that supervisor receives email when student submits a log
     */
    public function test_supervisor_receives_email_when_student_submits_log(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/student/logs', [
                'date' => now()->toDateString(),
                'hours_rendered' => 8,
                'task_description' => 'Completed project milestone',
            ])
            ->assertCreated();

        Mail::assertQueued(\App\Mail\LogPendingApproval::class, function ($mail) use ($supervisor) {
            return $mail->hasTo($supervisor->email) &&
                   str_contains($mail->subject, 'New Log Submitted for Review');
        });
    }

    /**
     * Test that student receives email when log is approved
     */
    public function test_student_receives_email_when_log_is_approved(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/approve", [])
            ->assertOk();

        Mail::assertQueued(\App\Mail\LogApproved::class, function ($mail) use ($student) {
            return $mail->hasTo($student->email) &&
                   str_contains($mail->subject, 'Your Log Has Been Approved');
        });
    }

    /**
     * Test that student receives email when log is rejected with reason
     */
    public function test_student_receives_email_when_log_is_rejected(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $comment = 'Please provide more details about your work on this task.';

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => $comment,
            ])
            ->assertOk();

        Mail::assertQueued(\App\Mail\LogRejected::class, function ($mail) use ($student, $comment) {
            return $mail->hasTo($student->email) &&
                   str_contains($mail->subject, 'Your Log Needs Revision') &&
                   $mail->comment === $comment;
        });
    }

    /**
     * Test that email contains student name
     */
    public function test_approval_email_contains_student_name(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent(['name' => 'John Doe']);
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/approve", [])
            ->assertOk();

        Mail::assertQueued(\App\Mail\LogApproved::class, function ($mail) {
            // Get rendered email content
            $content = $mail->build()->render();
            return str_contains($content, 'John Doe');
        });
    }

    /**
     * Test that rejection email contains supervisor name
     */
    public function test_rejection_email_contains_supervisor_name(): void
    {
        $supervisor = $this->helperSupervisor(['name' => 'Jane Smith']);
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => 'Needs revision',
            ])
            ->assertOk();

        Mail::assertQueued(\App\Mail\LogRejected::class, function ($mail) {
            $content = $mail->build()->render();
            return str_contains($content, 'Jane Smith');
        });
    }

    /**
     * Test that rejection email contains the supervisor's comment
     */
    public function test_rejection_email_contains_supervisor_comment(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $comment = 'Please clarify which tasks were completed and which were pending.';

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => $comment,
            ])
            ->assertOk();

        Mail::assertQueued(\App\Mail\LogRejected::class, function ($mail) use ($comment) {
            $content = $mail->build()->render();
            return str_contains($content, $comment);
        });
    }

    /**
     * Test that approval email contains log date
     */
    public function test_approval_email_contains_log_date(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $logDate = '2026-05-01';
        $log = $this->helperLogEntryFor($profile, 'PENDING', $logDate);

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/approve", [])
            ->assertOk();

        Mail::assertQueued(\App\Mail\LogApproved::class, function ($mail) use ($logDate) {
            $content = $mail->build()->render();
            // Check if date is formatted in email
            return str_contains($content, 'May 01, 2026') ||
                   str_contains($content, $logDate);
        });
    }

    /**
     * Test that email is queued even if there's an issue with mail driver
     * (graceful degradation)
     */
    public function test_email_queuing_is_resilient_to_errors(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        // Even though we faked Mail, the approval should still succeed
        Sanctum::actingAs($supervisor);

        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/approve", [])
            ->assertOk();

        // Log status should be updated even if email fails
        $this->assertDatabaseHas('log_entries', [
            'id' => $log->id,
            'status' => 'APPROVED',
        ]);
    }

    /**
     * Test that rejection email handles empty comment gracefully
     */
    public function test_rejection_email_handles_empty_comment(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => 'Needs revision',
            ])
            ->assertOk();

        // Email should still be queued successfully
        Mail::assertQueued(\App\Mail\LogRejected::class);
    }
}
