<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SupervisorInternListingPaginationTest extends TestCase
{
    use RefreshDatabase;

    public function test_supervisor_intern_list_returns_paginated_assigned_profiles(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $otherSupervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');
        $profiles = [];

        for ($index = 1; $index <= 25; $index++) {
            $student = $this->createUserWithRole('Student', [
                'name' => "Assigned Student {$index}",
                'email' => "assigned{$index}@example.com",
            ]);

            $profiles[] = $this->createInternshipProfileFor(
                student: $student,
                supervisor: $supervisor,
                adviser: $adviser,
                companyName: "Assigned Company {$index}"
            );
        }

        $unassignedStudent = $this->createUserWithRole('Student');
        $unassignedProfile = $this->createInternshipProfileFor(
            student: $unassignedStudent,
            supervisor: $otherSupervisor,
            adviser: $adviser,
            companyName: 'Unassigned Company'
        );

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/interns?page=2&per_page=10')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonCount(10, 'data')
            ->assertJsonPath('data.0.id', $profiles[10]->id)
            ->assertJsonPath('meta.current_page', 2)
            ->assertJsonPath('meta.last_page', 3)
            ->assertJsonPath('meta.per_page', 10)
            ->assertJsonPath('meta.total', 25)
            ->assertJsonPath('meta.has_more_pages', true)
            ->assertJsonMissing(['id' => $unassignedProfile->id]);
    }

    public function test_supervisor_intern_list_supports_search_within_assigned_profiles(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        $otherSupervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');
        $matchedStudent = $this->createUserWithRole('Student', [
            'name' => 'Maria Santos',
            'email' => 'maria.santos@example.com',
        ]);
        $otherStudent = $this->createUserWithRole('Student', [
            'name' => 'John Cruz',
            'email' => 'john.cruz@example.com',
        ]);

        $matchedProfile = $this->createInternshipProfileFor(
            student: $matchedStudent,
            supervisor: $supervisor,
            adviser: $adviser,
            companyName: 'Northwind Studio'
        );
        $otherProfile = $this->createInternshipProfileFor(
            student: $otherStudent,
            supervisor: $supervisor,
            adviser: $adviser,
            companyName: 'Acme Corp'
        );
        $unassignedMatch = $this->createInternshipProfileFor(
            student: $this->createUserWithRole('Student', ['name' => 'Maria Outside']),
            supervisor: $otherSupervisor,
            adviser: $adviser,
            companyName: 'Northwind Studio'
        );

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/interns?search=maria')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $matchedProfile->id)
            ->assertJsonPath('meta.total', 1)
            ->assertJsonMissing(['id' => $otherProfile->id])
            ->assertJsonMissing(['id' => $unassignedMatch->id]);
    }

    public function test_supervisor_intern_list_rejects_invalid_page_size(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor');
        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/interns?per_page=25')
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

    public function test_non_supervisor_cannot_view_supervisor_intern_list(): void
    {
        $student = $this->createUserWithRole('Student');
        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/interns')
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
}
