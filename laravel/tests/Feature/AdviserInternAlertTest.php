<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdviserInternAlertTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_active_internship_with_no_logs_returns_no_logs_alert(): void
    {
        Carbon::setTestNow('2026-04-20 09:00:00');
        [$adviser, $profile] = $this->createAssignedProfile();

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns')
            ->assertOk()
            ->assertJsonPath('data.0.id', $profile->id)
            ->assertJsonPath('data.0.alert_status', 'NO_LOGS_YET')
            ->assertJsonPath('data.0.alert.message', 'No logs submitted yet for this active internship.')
            ->assertJsonPath('data.0.alert.meta.server_date', '2026-04-20');
    }

    public function test_recent_logs_and_reasonable_timeline_progress_returns_on_track(): void
    {
        Carbon::setTestNow('2026-04-20 09:00:00');
        [$adviser, $profile] = $this->createAssignedProfile(requiredHours: 160);
        $this->createLogEntryFor($profile, 'APPROVED', 80, '2026-04-20');

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns')
            ->assertOk()
            ->assertJsonPath('data.0.alert_status', 'ON_TRACK')
            ->assertJsonPath('data.0.alert_severity', 'success');
    }

    public function test_inactive_beyond_working_day_threshold_returns_inactive(): void
    {
        Carbon::setTestNow('2026-04-20 09:00:00');
        [$adviser, $profile] = $this->createAssignedProfile(requiredHours: 160);
        $this->createLogEntryFor($profile, 'APPROVED', 90, '2026-04-14');

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns')
            ->assertOk()
            ->assertJsonPath('data.0.alert_status', 'INACTIVE')
            ->assertJsonPath('data.0.alert.message', 'No log submitted for 4 working days.')
            ->assertJsonPath('data.0.alert.meta.inactive_working_days', 4);
    }

    public function test_early_stage_student_is_not_marked_behind(): void
    {
        Carbon::setTestNow('2026-04-08 09:00:00');
        [$adviser, $profile] = $this->createAssignedProfile(requiredHours: 160);
        $this->createLogEntryFor($profile, 'APPROVED', 1, '2026-04-08');

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns')
            ->assertOk()
            ->assertJsonPath('data.0.alert_status', 'ON_TRACK')
            ->assertJsonPath('data.0.alert.meta.elapsed_working_days', 3);
    }

    public function test_insufficient_progress_relative_to_timeline_returns_behind(): void
    {
        Carbon::setTestNow('2026-04-20 09:00:00');
        [$adviser, $profile] = $this->createAssignedProfile(requiredHours: 160);
        $this->createLogEntryFor($profile, 'APPROVED', 40, '2026-04-20');

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns')
            ->assertOk()
            ->assertJsonPath('data.0.alert_status', 'BEHIND')
            ->assertJsonPath('data.0.alert_severity', 'warning')
            ->assertJsonPath('data.0.alert.meta.expected_hours_by_now', 88);
    }

    public function test_internship_before_start_date_is_not_flagged(): void
    {
        Carbon::setTestNow('2026-04-20 09:00:00');
        [$adviser] = $this->createAssignedProfile(
            startDate: '2026-04-27',
            endDate: '2026-05-22',
            requiredHours: 160
        );

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns')
            ->assertOk()
            ->assertJsonPath('data.0.alert_status', 'ON_TRACK')
            ->assertJsonPath('data.0.alert.message', 'Internship has not started yet.');
    }

    private function createAssignedProfile(
        string $startDate = '2026-04-06',
        string $endDate = '2026-05-01',
        int $requiredHours = 160
    ): array {
        $supervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');
        $student = $this->createUserWithRole('Student');

        $profile = InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor->id,
            'adviser_id' => $adviser->id,
            'company_name' => 'Acme Corp',
            'company_address' => '123 Main St',
            'required_hours' => $requiredHours,
            'start_date' => $startDate,
            'end_date' => $endDate,
        ]);

        return [$adviser, $profile];
    }

    private function createUserWithRole(string $roleName): User
    {
        return User::factory()->create([
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
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
            'submitted_at' => Carbon::parse($date)->setTime(17, 0),
        ]);
    }
}
