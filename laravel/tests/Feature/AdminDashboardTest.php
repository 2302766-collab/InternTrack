<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminDashboardTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_retrieve_system_wide_dashboard_metrics(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $supervisor = $this->createUserWithRole('Supervisor');

        $studentOne = $this->createUserWithRole('Student');
        $studentTwo = $this->createUserWithRole('Student');
        $studentThree = $this->createUserWithRole('Student');

        $profileOne = $this->createInternshipProfileFor($studentOne, $supervisor, 40);
        $profileTwo = $this->createInternshipProfileFor($studentTwo, $supervisor, 20);

        $this->createLogEntryFor($profileOne, 'APPROVED', 8, '2026-03-01');
        $this->createLogEntryFor($profileOne, 'APPROVED', 8, '2026-03-02');
        $this->createLogEntryFor($profileOne, 'PENDING', 6, '2026-03-03');
        $this->createLogEntryFor($profileTwo, 'APPROVED', 10, '2026-03-01');
        $this->createLogEntryFor($profileTwo, 'PENDING', 5, '2026-03-02');
        $this->createLogEntryFor($profileTwo, 'REJECTED', 4, '2026-03-03');

        Sanctum::actingAs($admin);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Admin dashboard metrics retrieved successfully.')
            ->assertJsonPath('data.total_students', 3)
            ->assertJsonPath('data.pending_logs', 2)
            ->assertJsonPath('data.approved_logs', 3)
            ->assertJsonPath('data.average_completion_percentage', 30);
    }

    public function test_non_admin_cannot_retrieve_dashboard_metrics(): void
    {
        $student = $this->createUserWithRole('Student');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/admin/dashboard')
            ->assertForbidden()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Only admins can access dashboard metrics.');
    }

    private function createUserWithRole(string $roleName): User
    {
        return User::factory()->create([
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
        ]);
    }

    private function createInternshipProfileFor(
        User $student,
        ?User $supervisor = null,
        int $requiredHours = 486
    ): InternshipProfile {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor?->id,
            'company_name' => 'Acme Corp',
            'company_address' => '123 Main St',
            'required_hours' => $requiredHours,
            'start_date' => '2026-03-01',
            'end_date' => '2026-05-31',
        ]);
    }

    private function createLogEntryFor(
        InternshipProfile $profile,
        string $status,
        int $hoursRendered,
        string $date
    ): LogEntry {
        return LogEntry::create([
            'internship_profile_id' => $profile->id,
            'date' => $date,
            'hours_rendered' => $hoursRendered,
            'task_description' => "Tasks for {$status} on {$date}",
            'status' => $status,
            'submitted_at' => now(),
        ]);
    }
}
