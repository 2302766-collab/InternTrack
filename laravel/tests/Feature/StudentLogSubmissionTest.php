<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class StudentLogSubmissionTest extends TestCase
{
    use RefreshDatabase;

    public function test_student_can_submit_multiple_logs_for_the_same_date(): void
    {
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);

        Sanctum::actingAs($student);

        $payload = [
            'date' => now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Worked on first task block.',
        ];

        $this->withHeader('Accept', 'application/json')
            ->postJson('/api/v1/student/logs', $payload)
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log submitted successfully.');

        $this->withHeader('Accept', 'application/json')
            ->postJson('/api/v1/student/logs', [
                ...$payload,
                'task_description' => 'Worked on second task block.',
            ])
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log submitted successfully.');

        $this->assertDatabaseCount('log_entries', 2);
        $this->assertDatabaseHas('log_entries', [
            'internship_profile_id' => $profile->id,
            'date' => now()->toDateString(),
            'task_description' => 'Worked on first task block.',
        ]);
        $this->assertDatabaseHas('log_entries', [
            'internship_profile_id' => $profile->id,
            'date' => now()->toDateString(),
            'task_description' => 'Worked on second task block.',
        ]);
    }

    public function test_student_can_submit_log_for_yesterday(): void
    {
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $yesterday = now()->subDay()->toDateString();

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->postJson('/api/v1/student/logs', [
                'date' => $yesterday,
                'hours_rendered' => 8,
                'task_description' => 'Worked on yesterday task block.',
            ])
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log submitted successfully.')
            ->assertJsonPath('data.date', $yesterday);

        $this->assertDatabaseHas('log_entries', [
            'internship_profile_id' => $profile->id,
            'date' => $yesterday,
            'task_description' => 'Worked on yesterday task block.',
        ]);
    }

    public function test_student_cannot_submit_log_older_than_yesterday(): void
    {
        $student = $this->createStudent();
        $this->createInternshipProfileFor($student);

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->postJson('/api/v1/student/logs', [
                'date' => now()->subDays(2)->toDateString(),
                'hours_rendered' => 8,
                'task_description' => 'Too old task block.',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Validation failed.')
            ->assertJsonPath('data.errors.date.0', 'Log date must be today or yesterday.');

        $this->assertDatabaseCount('log_entries', 0);
    }

    public function test_student_cannot_submit_future_dated_log(): void
    {
        $student = $this->createStudent();
        $this->createInternshipProfileFor($student);

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->postJson('/api/v1/student/logs', [
                'date' => now()->addDay()->toDateString(),
                'hours_rendered' => 8,
                'task_description' => 'Future task block.',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Validation failed.')
            ->assertJsonPath('data.errors.date.0', 'Log date cannot be in the future.');

        $this->assertDatabaseCount('log_entries', 0);
    }

    public function test_student_can_update_a_pending_log_to_a_date_used_by_another_log(): void
    {
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $today = now()->toDateString();
        $yesterday = now()->subDay()->toDateString();

        $existingToday = $this->createLogEntryFor($profile, $today, 'Today log');
        $editableYesterday = $this->createLogEntryFor($profile, $yesterday, 'Yesterday log');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->putJson("/api/v1/student/logs/{$editableYesterday->id}", [
                'date' => $today,
                'hours_rendered' => 7,
                'task_description' => 'Moved to the same date.',
            ])
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log updated successfully.')
            ->assertJsonPath('data.date', $today);

        $this->assertDatabaseHas('log_entries', [
            'id' => $editableYesterday->id,
            'date' => $today,
            'task_description' => 'Moved to the same date.',
        ]);

        $this->assertDatabaseHas('log_entries', [
            'id' => $existingToday->id,
            'date' => $today,
            'task_description' => 'Today log',
        ]);
    }

    public function test_student_can_update_a_pending_log_to_yesterday(): void
    {
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $today = now()->toDateString();
        $yesterday = now()->subDay()->toDateString();
        $log = $this->createLogEntryFor($profile, $today, 'Today log');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->putJson("/api/v1/student/logs/{$log->id}", [
                'date' => $yesterday,
                'hours_rendered' => 7,
                'task_description' => 'Moved to yesterday.',
            ])
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log updated successfully.')
            ->assertJsonPath('data.date', $yesterday);

        $this->assertDatabaseHas('log_entries', [
            'id' => $log->id,
            'date' => $yesterday,
            'task_description' => 'Moved to yesterday.',
        ]);
    }

    public function test_student_cannot_update_a_pending_log_to_older_than_yesterday(): void
    {
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $today = now()->toDateString();
        $log = $this->createLogEntryFor($profile, $today, 'Today log');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->putJson("/api/v1/student/logs/{$log->id}", [
                'date' => now()->subDays(2)->toDateString(),
                'hours_rendered' => 7,
                'task_description' => 'Moved too far back.',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Validation failed.')
            ->assertJsonPath('data.errors.date.0', 'Log date must be today or yesterday.');

        $this->assertDatabaseHas('log_entries', [
            'id' => $log->id,
            'date' => $today,
            'task_description' => 'Today log',
        ]);
    }

    public function test_student_cannot_update_a_pending_log_to_a_future_date(): void
    {
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $today = now()->toDateString();
        $log = $this->createLogEntryFor($profile, $today, 'Today log');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->putJson("/api/v1/student/logs/{$log->id}", [
                'date' => now()->addDay()->toDateString(),
                'hours_rendered' => 7,
                'task_description' => 'Moved into future.',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Validation failed.')
            ->assertJsonPath('data.errors.date.0', 'Log date cannot be in the future.');

        $this->assertDatabaseHas('log_entries', [
            'id' => $log->id,
            'date' => $today,
            'task_description' => 'Today log',
        ]);
    }

    private function createStudent(): User
    {
        $studentRole = Role::query()->firstOrCreate(['name' => 'Student']);

        return User::factory()->create([
            'role_id' => $studentRole->id,
        ]);
    }

    private function createInternshipProfileFor(User $student): InternshipProfile
    {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'company_name' => 'Acme Corp',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->subDays(5)->toDateString(),
            'end_date' => now()->addDays(30)->toDateString(),
        ]);
    }

    private function createLogEntryFor(
        InternshipProfile $profile,
        string $date,
        string $taskDescription,
    ): LogEntry {
        return LogEntry::create([
            'internship_profile_id' => $profile->id,
            'date' => $date,
            'hours_rendered' => 8,
            'task_description' => $taskDescription,
            'status' => 'PENDING',
            'submitted_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
