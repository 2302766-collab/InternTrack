<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReportDataEndpointTest extends TestCase
{
    use RefreshDatabase;

    public function test_student_report_includes_only_approved_logs_and_summary(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student, $supervisor, 40);

        $firstApproved = $this->createLogEntryFor($profile, 'APPROVED', 8, '2026-03-01');
        $this->createLogEntryFor($profile, 'PENDING', 6, '2026-03-02');
        $secondApproved = $this->createLogEntryFor($profile, 'APPROVED', 16, '2026-03-03');
        $this->createLogEntryFor($profile, 'REJECTED', 4, '2026-03-04');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/report')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.student.id', $student->id)
            ->assertJsonPath('data.supervisor.id', $supervisor->id)
            ->assertJsonCount(2, 'data.logs')
            ->assertJsonPath('data.logs.0.id', $firstApproved->id)
            ->assertJsonPath('data.logs.1.id', $secondApproved->id)
            ->assertJsonPath('data.summary.approved_hours', 24)
            ->assertJsonPath('data.summary.total_approved_hours', 24)
            ->assertJsonPath('data.summary.required_hours', 40)
            ->assertJsonPath('data.summary.completion_percentage', 60);
    }

    public function test_student_report_returns_empty_logs_when_no_approved_logs_exist(): void
    {
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student);

        $this->createLogEntryFor($profile, 'PENDING', 8, '2026-03-01');
        $this->createLogEntryFor($profile, 'REJECTED', 8, '2026-03-02');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/report')
            ->assertOk()
            ->assertJsonCount(0, 'data.logs')
            ->assertJsonPath('data.summary.approved_hours', 0)
            ->assertJsonPath('data.summary.completion_percentage', 0);
    }

    public function test_student_report_applies_optional_date_filters(): void
    {
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student, requiredHours: 20);

        $this->createLogEntryFor($profile, 'APPROVED', 4, '2026-03-01');
        $includedLog = $this->createLogEntryFor($profile, 'APPROVED', 6, '2026-03-10');
        $this->createLogEntryFor($profile, 'APPROVED', 8, '2026-03-20');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/report?start_date=2026-03-05&end_date=2026-03-15')
            ->assertOk()
            ->assertJsonCount(1, 'data.logs')
            ->assertJsonPath('data.logs.0.id', $includedLog->id)
            ->assertJsonPath('data.date_range.start_date', '2026-03-05')
            ->assertJsonPath('data.date_range.end_date', '2026-03-15')
            ->assertJsonPath('data.summary.approved_hours', 6)
            ->assertJsonPath('data.summary.total_approved_hours', 6)
            ->assertJsonPath('data.summary.completion_percentage', 30);
    }

    public function test_supervisor_cannot_access_unassigned_student_report(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $otherSupervisor = $this->createUserWithRole('Supervisor');
        $student = $this->createUserWithRole('Student');
        $this->createInternshipProfileFor($student, $otherSupervisor);

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/supervisor/students/{$student->id}/report")
            ->assertForbidden()
            ->assertJsonPath('message', 'You are not allowed to access this student report.');
    }

    public function test_adviser_can_access_assigned_student_report(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student, $supervisor, 40, $adviser);

        $approvedLog = $this->createLogEntryFor($profile, 'APPROVED', 8, '2026-03-05');
        $this->createLogEntryFor($profile, 'PENDING', 4, '2026-03-06');

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/adviser/students/{$student->id}/report")
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.student.id', $student->id)
            ->assertJsonCount(1, 'data.logs')
            ->assertJsonPath('data.logs.0.id', $approvedLog->id)
            ->assertJsonPath('data.summary.approved_hours', 8)
            ->assertJsonPath('data.summary.required_hours', 40);
    }

    public function test_adviser_cannot_access_unassigned_student_report(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');
        $otherAdviser = $this->createUserWithRole('Adviser');
        $student = $this->createUserWithRole('Student');
        $this->createInternshipProfileFor($student, $supervisor, 486, $otherAdviser);

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/adviser/students/{$student->id}/report")
            ->assertForbidden()
            ->assertJsonPath('message', 'You are not allowed to access this student report.');
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
        int $requiredHours = 486,
        ?User $adviser = null
    ): InternshipProfile {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor?->id,
            'adviser_id' => $adviser?->id,
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
