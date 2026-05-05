<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdviserInternDetailTest extends TestCase
{
    use RefreshDatabase;

    public function test_adviser_list_includes_progress_summary_for_dashboard(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student, $supervisor, $adviser);

        $this->createLogEntryFor($profile, 'APPROVED', 8, '2026-04-01');
        $this->createLogEntryFor($profile, 'PENDING', 6, '2026-04-05');

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns')
            ->assertOk()
            ->assertJsonPath('data.0.id', $profile->id)
            ->assertJsonPath('data.0.student_id', $student->id)
            ->assertJsonPath('data.0.completed_hours', 8)
            ->assertJsonPath('data.0.total_logs', 2)
            ->assertJsonPath('data.0.pending_logs', 1)
            ->assertJsonPath('data.0.approved_logs', 1)
            ->assertJsonPath('data.0.rejected_logs', 0)
            ->assertJsonPath('data.0.last_log_date', '2026-04-05');
    }

    public function test_adviser_can_view_assigned_intern_detail_with_progress(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student, $supervisor, $adviser);

        $approvedLog = $this->createLogEntryFor($profile, 'APPROVED', 8, now()->subDays(3)->toDateString());
        $pendingLog = $this->createLogEntryFor($profile, 'PENDING', 6, now()->subDays(1)->toDateString());
        $rejectedLog = $this->createLogEntryFor($profile, 'REJECTED', 4, now()->subDays(2)->toDateString());

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/adviser/interns/{$profile->id}")
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.id', $profile->id)
            ->assertJsonPath('data.student_name', $student->name)
            ->assertJsonPath('data.student_email', $student->email)
            ->assertJsonPath('data.supervisor_name', $supervisor->name)
            ->assertJsonPath('data.adviser_name', $adviser->name)
            ->assertJsonPath('data.progress.completed_hours', 8)
            ->assertJsonPath('data.progress.total_logs', 3)
            ->assertJsonPath('data.progress.pending_logs', 1)
            ->assertJsonPath('data.progress.approved_logs', 1)
            ->assertJsonPath('data.progress.rejected_logs', 1)
            ->assertJsonPath('data.recent_logs.0.id', $pendingLog->id)
            ->assertJsonPath('data.recent_logs.1.id', $rejectedLog->id)
            ->assertJsonPath('data.recent_logs.2.id', $approvedLog->id);
    }

    public function test_adviser_cannot_view_unassigned_intern_detail(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');
        $otherAdviser = $this->createUserWithRole('Adviser');
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student, $supervisor, $otherAdviser);

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/adviser/interns/{$profile->id}")
            ->assertStatus(403)
            ->assertJsonPath('message', 'You are not allowed to access this intern.');
    }

    public function test_non_adviser_cannot_view_adviser_intern_detail(): void
    {
        $student = $this->createUserWithRole('Student');
        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns/1')
            ->assertStatus(403);
    }

    private function createUserWithRole(string $roleName): User
    {
        return User::factory()->create([
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
        ]);
    }

    private function createInternshipProfileFor(
        User $student,
        User $supervisor,
        User $adviser
    ): InternshipProfile {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor->id,
            'adviser_id' => $adviser->id,
            'company_name' => 'Acme Corp',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->subDays(10)->toDateString(),
            'end_date' => now()->addDays(30)->toDateString(),
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
            'task_description' => "Tasks for {$status}",
            'status' => $status,
            'submitted_at' => now(),
        ]);
    }
}
