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

class SupervisorDashboardTest extends TestCase
{
    use RefreshDatabase;

    public function test_supervisor_can_view_dashboard_metrics(): void
    {
        $supervisor = $this->createSupervisor();
        $studentA = $this->createStudent();
        $studentB = $this->createStudent();

        $profileA = $this->createInternshipProfileFor($studentA, $supervisor);
        $profileB = $this->createInternshipProfileFor($studentB, $supervisor);

        $pendingLog = $this->createLogEntryFor($profileA, status: 'PENDING');
        $approvedLog = $this->createLogEntryFor($profileB, status: 'APPROVED');

        LogAction::create([
            'log_entry_id' => $approvedLog->id,
            'supervisor_id' => $supervisor->id,
            'action' => 'APPROVED',
            'comment' => 'Looks good.',
            'acted_at' => now(),
        ]);

        LogAction::create([
            'log_entry_id' => $pendingLog->id,
            'supervisor_id' => $supervisor->id,
            'action' => 'APPROVED',
            'comment' => 'Old approval should not count today.',
            'acted_at' => now()->subDay(),
        ]);

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/dashboard')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.pending_review', 1)
            ->assertJsonPath('data.approved_today', 1)
            ->assertJsonPath('data.total_students', 2);
    }

    public function test_non_supervisor_cannot_view_dashboard_metrics(): void
    {
        Sanctum::actingAs($this->createStudent());

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/dashboard')
            ->assertForbidden();
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
