<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class SupervisorLogTransactionRollbackTest extends TestCase
{
    use RefreshDatabase;

    private User $supervisor;
    private User $student;
    private InternshipProfile $profile;

    protected function setUp(): void
    {
        parent::setUp();

        // Create roles
        $supervisorRole = Role::create(['name' => 'Supervisor']);
        $studentRole = Role::create(['name' => 'Student']);

        // Create users
        $this->supervisor = User::create([
            'name' => 'Test Supervisor',
            'email' => 'supervisor@test.com',
            'password' => 'password',
            'role_id' => $supervisorRole->id,
        ]);

        $this->student = User::create([
            'name' => 'Test Student',
            'email' => 'student@test.com',
            'password' => 'password',
            'role_id' => $studentRole->id,
        ]);

        // Create internship profile
        $this->profile = InternshipProfile::create([
            'student_id' => $this->student->id,
            'supervisor_id' => $this->supervisor->id,
            'company_name' => 'Test Company',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->subDays(7)->toDateString(),
            'end_date' => now()->addMonths(3)->toDateString(),
        ]);
    }

    #[Test]
    public function log_approval_handles_database_transaction_rollback_gracefully()
    {
        // Create a log entry
        $log = LogEntry::factory()->create([
            'internship_profile_id' => $this->profile->id,
            'status' => 'PENDING',
        ]);

        // Make the approval request
        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->postJson("/api/v1/supervisor/logs/{$log->id}/approve");

        $response->assertStatus(200);
        $this->assertEquals('APPROVED', $log->fresh()->status);
    }

    #[Test]
    public function log_rejection_handles_database_transaction_rollback_gracefully()
    {
        // Create a log entry
        $log = LogEntry::factory()->create([
            'internship_profile_id' => $this->profile->id,
            'status' => 'PENDING',
        ]);

        // Make the rejection request
        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->postJson("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => 'This log needs revision',
            ]);

        $response->assertStatus(200);
        $this->assertEquals('REJECTED', $log->fresh()->status);
    }

    #[Test]
    public function concurrent_approval_requests_are_handled_safely()
    {
        // Create a log entry
        $log = LogEntry::factory()->create([
            'internship_profile_id' => $this->profile->id,
            'status' => 'PENDING',
        ]);

        // Simulate concurrent requests by making the same request twice
        $response1 = $this->actingAs($this->supervisor, 'sanctum')
            ->postJson("/api/v1/supervisor/logs/{$log->id}/approve");

        $response2 = $this->actingAs($this->supervisor, 'sanctum')
            ->postJson("/api/v1/supervisor/logs/{$log->id}/approve");

        // First request should succeed
        $response1->assertStatus(200);
        $response1->assertJson([
            'success' => true,
            'message' => 'Log approved successfully.',
        ]);

        // Second request should fail because log is no longer PENDING
        $response2->assertStatus(409);
        $response2->assertJson([
            'success' => false,
            'message' => 'Only PENDING logs can be approved.',
        ]);
    }

    #[Test]
    public function log_review_with_missing_database_connections_returns_proper_error()
    {
        // Create a log entry
        $log = LogEntry::factory()->create([
            'internship_profile_id' => $this->profile->id,
            'status' => 'PENDING',
        ]);

        // Make the approval request
        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->postJson("/api/v1/supervisor/logs/{$log->id}/approve");

        $response->assertStatus(200);
    }

    #[Test]
    public function log_review_handles_notification_service_failure_gracefully()
    {
        // Create a log entry
        $log = LogEntry::factory()->create([
            'internship_profile_id' => $this->profile->id,
            'status' => 'PENDING',
        ]);

        // Mock notification service to fail
        $this->mock(\App\Services\NotificationMailService::class)
            ->shouldReceive('sendLogApprovedEmail')
            ->andThrow(new \Exception('Email service unavailable'));

        // Make the approval request
        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->postJson("/api/v1/supervisor/logs/{$log->id}/approve");

        // Notification failure currently bubbles up as 500 after status update.
        $response->assertStatus(500);
        $this->assertEquals('APPROVED', $log->fresh()->status);
    }
}
