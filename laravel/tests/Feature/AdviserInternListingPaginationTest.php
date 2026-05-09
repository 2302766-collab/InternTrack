<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdviserInternListingPaginationTest extends TestCase
{
    use RefreshDatabase;

    public function test_adviser_intern_list_returns_paginated_response_with_progress_summaries(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');
        $otherAdviser = $this->createUserWithRole('Adviser');
        $profiles = [];

        for ($index = 1; $index <= 12; $index++) {
            $student = $this->createUserWithRole('Student', [
                'name' => "Advisee {$index}",
                'email' => "advisee{$index}@example.com",
            ]);

            $profiles[] = $this->createInternshipProfileFor(
                student: $student,
                supervisor: $supervisor,
                adviser: $adviser,
                companyName: "Advisee Company {$index}"
            );
        }

        $this->createLogEntryFor($profiles[10], 'APPROVED', 8, '2026-04-01');
        $this->createLogEntryFor($profiles[10], 'PENDING', 6, '2026-04-05');

        $unassignedProfile = $this->createInternshipProfileFor(
            student: $this->createUserWithRole('Student'),
            supervisor: $supervisor,
            adviser: $otherAdviser,
            companyName: 'Other Adviser Company'
        );

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns?page=2&per_page=10')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $profiles[10]->id)
            ->assertJsonPath('data.0.completed_hours', 8)
            ->assertJsonPath('data.0.total_logs', 2)
            ->assertJsonPath('data.0.pending_logs', 1)
            ->assertJsonPath('data.0.approved_logs', 1)
            ->assertJsonPath('data.0.rejected_logs', 0)
            ->assertJsonPath('data.0.last_log_date', '2026-04-05')
            ->assertJsonPath('meta.current_page', 2)
            ->assertJsonPath('meta.last_page', 2)
            ->assertJsonPath('meta.per_page', 10)
            ->assertJsonPath('meta.total', 12)
            ->assertJsonPath('meta.from', 11)
            ->assertJsonPath('meta.to', 12)
            ->assertJsonPath('meta.has_more_pages', false)
            ->assertJsonMissing(['id' => $unassignedProfile->id]);
    }

    public function test_adviser_intern_list_supports_search_within_assigned_profiles(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');
        $otherAdviser = $this->createUserWithRole('Adviser');

        $matchedProfile = $this->createInternshipProfileFor(
            student: $this->createUserWithRole('Student', [
                'name' => 'Ana Cruz',
                'email' => 'ana.cruz@example.com',
            ]),
            supervisor: $supervisor,
            adviser: $adviser,
            companyName: 'Blue Harbor'
        );
        $otherProfile = $this->createInternshipProfileFor(
            student: $this->createUserWithRole('Student', [
                'name' => 'Ben Reyes',
                'email' => 'ben.reyes@example.com',
            ]),
            supervisor: $supervisor,
            adviser: $adviser,
            companyName: 'Green Yard'
        );
        $unassignedMatch = $this->createInternshipProfileFor(
            student: $this->createUserWithRole('Student', [
                'name' => 'Ana Outside',
                'email' => 'ana.outside@example.com',
            ]),
            supervisor: $supervisor,
            adviser: $otherAdviser,
            companyName: 'Blue Harbor'
        );

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns?search=ana')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $matchedProfile->id)
            ->assertJsonPath('meta.total', 1)
            ->assertJsonMissing(['id' => $otherProfile->id])
            ->assertJsonMissing(['id' => $unassignedMatch->id]);
    }

    public function test_adviser_intern_list_rejects_invalid_page_size(): void
    {
        $adviser = $this->createUserWithRole('Adviser');
        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns?per_page=25')
            ->assertStatus(422)
            ->assertJsonPath('message', 'Validation failed.')
            ->assertJsonStructure([
                'data' => [
                    'errors' => [
                        'per_page',
                    ],
                ],
            ]);
    }

    public function test_adviser_intern_list_rejects_invalid_page_number(): void
    {
        $adviser = $this->createUserWithRole('Adviser');
        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns?page=0')
            ->assertStatus(422)
            ->assertJsonPath('message', 'Validation failed.')
            ->assertJsonStructure([
                'data' => [
                    'errors' => [
                        'page',
                    ],
                ],
            ]);
    }

    public function test_non_adviser_cannot_view_adviser_intern_list(): void
    {
        $student = $this->createUserWithRole('Student');
        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/interns')
            ->assertStatus(403);
    }

    private function createUserWithRole(string $roleName, array $attributes = []): User
    {
        return User::factory()->create(array_merge($attributes, [
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
        ]));
    }

    private function createInternshipProfileFor(
        User $student,
        User $supervisor,
        User $adviser,
        string $companyName
    ): InternshipProfile {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor->id,
            'adviser_id' => $adviser->id,
            'company_name' => $companyName,
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
