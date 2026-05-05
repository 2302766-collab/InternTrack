<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SupervisorLogListingTest extends TestCase
{
    use RefreshDatabase;

    public function test_returns_empty_list_when_supervisor_has_no_assigned_students(): void
    {
        $supervisor = $this->createSupervisor();
        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/logs')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonCount(0, 'data');
    }

    public function test_supervisor_sees_only_assigned_pending_logs_sorted_oldest_first(): void
    {
        $supervisor = $this->createSupervisor();
        $otherSupervisor = $this->createSupervisor();

        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);

        $olderPending = $this->createLogEntryFor($profile, 'PENDING', now()->subDays(2)->toDateString());
        $newerPending = $this->createLogEntryFor($profile, 'PENDING', now()->toDateString());
        $this->createLogEntryFor($profile, 'APPROVED', now()->subDay()->toDateString()); // should be excluded

        $otherStudent = $this->createStudent();
        $otherProfile = $this->createInternshipProfileFor($otherStudent, $otherSupervisor);
        $this->createLogEntryFor($otherProfile, 'PENDING', now()->subDays(3)->toDateString());

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/logs')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $olderPending->id)
            ->assertJsonPath('data.0.status', 'PENDING')
            ->assertJsonPath('data.1.id', $newerPending->id)
            ->assertJsonPath('data.1.status', 'PENDING');
    }

    public function test_non_supervisor_cannot_access_logs(): void
    {
        $student = $this->createStudent();
        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/logs')
            ->assertStatus(403);
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
        string $status = 'PENDING',
        ?string $date = null
    ): LogEntry {
        return LogEntry::create([
            'internship_profile_id' => $profile->id,
            'date' => $date ?? now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Reviewed project updates.',
            'status' => $status,
            'submitted_at' => now(),
        ]);
    }
}
