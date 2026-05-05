<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogAction;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SupervisorLogApprovalTest extends TestCase
{
    use RefreshDatabase;

    public function test_supervisor_can_approve_owned_pending_log(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/approve", [
                'comment' => 'Great progress on the assigned tasks.',
            ])
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log approved successfully.')
            ->assertJsonPath('data.status', 'APPROVED')
            ->assertJsonPath('data.review_history.0.action', 'APPROVED')
            ->assertJsonPath('data.review_history.0.comment', 'Great progress on the assigned tasks.');

        $this->assertDatabaseHas('log_entries', [
            'id' => $log->id,
            'status' => 'APPROVED',
        ]);

        $this->assertDatabaseHas('log_actions', [
            'log_entry_id' => $log->id,
            'supervisor_id' => $supervisor->id,
            'action' => 'APPROVED',
            'comment' => 'Great progress on the assigned tasks.',
        ]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $student->id,
            'title' => 'Log approved',
            'message' => "Your log for {$log->date} was approved by {$supervisor->name}.",
            'is_read' => false,
        ]);
    }

    public function test_supervisor_can_reject_owned_pending_log_with_comment(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => 'Please attach your proof of work before resubmitting.',
            ])
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log rejected successfully.')
            ->assertJsonPath('data.status', 'REJECTED')
            ->assertJsonPath('data.review_history.0.action', 'REJECTED')
            ->assertJsonPath('data.review_history.0.supervisor.id', $supervisor->id)
            ->assertJsonPath(
                'data.review_history.0.comment',
                'Please attach your proof of work before resubmitting.'
            );

        $this->assertDatabaseHas('log_entries', [
            'id' => $log->id,
            'status' => 'REJECTED',
        ]);

        $this->assertDatabaseHas('log_actions', [
            'log_entry_id' => $log->id,
            'supervisor_id' => $supervisor->id,
            'action' => 'REJECTED',
            'comment' => 'Please attach your proof of work before resubmitting.',
        ]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $student->id,
            'title' => 'Log rejected',
            'message' => "Your log for {$log->date} was rejected by {$supervisor->name}. Comment: Please attach your proof of work before resubmitting.",
            'is_read' => false,
        ]);

        $this->assertNotNull(
            LogAction::query()
                ->where('log_entry_id', $log->id)
                ->where('supervisor_id', $supervisor->id)
                ->value('acted_at')
        );
    }

    public function test_reject_requires_comment(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => '',
            ])
            ->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Rejection comment is required.')
            ->assertJsonPath('data.errors.comment.0', 'Rejection comment is required.');
    }

    public function test_reject_requires_comment_with_minimum_length(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => 'no',
            ])
            ->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Validation failed.')
            ->assertJsonPath(
                'data.errors.comment.0',
                'The comment field must be at least 3 characters.'
            );
    }

    public function test_cannot_approve_non_pending_log(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'APPROVED');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/approve")
            ->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Only PENDING logs can be approved.');
    }

    public function test_cannot_reject_non_pending_log(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile, 'APPROVED');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => 'Please correct the hours rendered.',
            ])
            ->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Only PENDING logs can be rejected.');
    }

    public function test_cannot_approve_log_not_owned_by_supervisor(): void
    {
        $supervisor = $this->createSupervisor();
        $otherSupervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $otherSupervisor);
        $log = $this->createLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/approve")
            ->assertStatus(403)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'You are not allowed to approve this log.');
    }

    public function test_cannot_reject_log_not_owned_by_supervisor(): void
    {
        $supervisor = $this->createSupervisor();
        $otherSupervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $otherSupervisor);
        $log = $this->createLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => 'Please attach your proof of work before resubmitting.',
            ])
            ->assertStatus(403)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'You are not allowed to reject this log.');
    }

    public function test_non_supervisor_cannot_approve(): void
    {
        $student = $this->createStudent();
        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/supervisor/logs/1/approve')
            ->assertStatus(403);
    }

    public function test_non_supervisor_cannot_reject(): void
    {
        $student = $this->createStudent();
        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/supervisor/logs/1/reject', [
                'comment' => 'Please correct the entry.',
            ])
            ->assertStatus(403)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Only supervisors can reject logs.');
    }

    public function test_approving_missing_log_returns_404(): void
    {
        $supervisor = $this->createSupervisor();
        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/supervisor/logs/999999/approve')
            ->assertNotFound()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Log not found.');
    }

    private function createRole(string $name): Role
    {
        return Role::query()->firstOrCreate(['name' => $name]);
    }

    private function createSupervisor(): User
    {
        return User::factory()->create([
            'role_id' => $this->createRole('Supervisor')->id,
        ]);
    }

    private function createStudent(): User
    {
        return User::factory()->create([
            'role_id' => $this->createRole('Student')->id,
        ]);
    }

    private function createInternshipProfileFor(User $student, User $supervisor): InternshipProfile
    {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor->id,
            'company_name' => 'Acme Corp',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->subDays(5)->toDateString(),
            'end_date' => now()->addDays(30)->toDateString(),
        ]);
    }

    private function createLogEntryFor(
        InternshipProfile $profile,
        string $status = 'PENDING'
    ): LogEntry {
        return LogEntry::create([
            'internship_profile_id' => $profile->id,
            'date' => now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Reviewed project updates.',
            'status' => $status,
            'submitted_at' => now(),
        ]);
    }
}
