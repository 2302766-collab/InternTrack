<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminStudentListingTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_retrieve_paginated_students_with_progress_metrics(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $supervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');

        $studentOne = $this->createUserWithRole('Student', 'Student One');
        $studentTwo = $this->createUserWithRole('Student', 'Student Two');
        $studentThree = $this->createUserWithRole('Student', 'Student Three');
        $this->createUserWithRole('Supervisor', 'Not A Student');

        $profileOne = $this->createInternshipProfileFor($studentOne, $supervisor, 40, 'Acme Corp');
        $profileTwo = $this->createInternshipProfileFor($studentTwo, $supervisor, 20, 'Beta LLC');
        $profileTwo->update([
            'adviser_id' => $adviser->id,
        ]);

        $this->createLogEntryFor($profileOne, 'APPROVED', 8, '2026-03-01');
        $this->createLogEntryFor($profileOne, 'APPROVED', 8, '2026-03-02');
        $this->createLogEntryFor($profileOne, 'PENDING', 4, '2026-03-03');
        $this->createLogEntryFor($profileTwo, 'APPROVED', 10, '2026-03-01');
        $this->createLogEntryFor($profileTwo, 'REJECTED', 4, '2026-03-02');

        Sanctum::actingAs($admin);

        $response = $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/admin/students');

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Admin students retrieved successfully.')
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.per_page', 10)
            ->assertJsonPath('meta.total', 3)
            ->assertJsonPath('meta.last_page', 1)
            ->assertJsonPath('meta.has_more_pages', false);

        $this->assertSame([
            [
                'student_id' => $studentOne->id,
                'name' => 'Student One',
                'company' => 'Acme Corp',
                'approved_hours' => 16,
                'required_hours' => 40,
                'completion_percentage' => 40,
                'has_internship_profile' => true,
                'has_supervisor' => true,
                'has_adviser' => false,
            ],
            [
                'student_id' => $studentTwo->id,
                'name' => 'Student Two',
                'company' => 'Beta LLC',
                'approved_hours' => 10,
                'required_hours' => 20,
                'completion_percentage' => 50,
                'has_internship_profile' => true,
                'has_supervisor' => true,
                'has_adviser' => true,
            ],
            [
                'student_id' => $studentThree->id,
                'name' => 'Student Three',
                'company' => null,
                'approved_hours' => 0,
                'required_hours' => 0,
                'completion_percentage' => 0,
                'has_internship_profile' => false,
                'has_supervisor' => false,
                'has_adviser' => false,
            ],
        ], $response->json('data'));
    }

    public function test_students_endpoint_is_paginated(): void
    {
        $admin = $this->createUserWithRole('Admin');

        for ($i = 1; $i <= 11; $i++) {
            $this->createUserWithRole('Student', "Student {$i}");
        }

        Sanctum::actingAs($admin);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/admin/students')
            ->assertOk()
            ->assertJsonCount(10, 'data')
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.per_page', 10)
            ->assertJsonPath('meta.total', 11)
            ->assertJsonPath('meta.last_page', 2)
            ->assertJsonPath('meta.has_more_pages', true);
    }

    public function test_students_endpoint_respects_requested_page_and_page_size(): void
    {
        $admin = $this->createUserWithRole('Admin');

        for ($i = 1; $i <= 15; $i++) {
            $this->createUserWithRole('Student', "Student {$i}");
        }

        Sanctum::actingAs($admin);

        $response = $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/admin/students?page=2&per_page=10');

        $response->assertOk()
            ->assertJsonCount(5, 'data')
            ->assertJsonPath('data.0.name', 'Student 11')
            ->assertJsonPath('meta.current_page', 2)
            ->assertJsonPath('meta.per_page', 10)
            ->assertJsonPath('meta.total', 15)
            ->assertJsonPath('meta.last_page', 2)
            ->assertJsonPath('meta.has_more_pages', false);
    }

    public function test_students_endpoint_can_filter_students_with_missing_advisers(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $supervisor = $this->createUserWithRole('Supervisor');
        $adviser = $this->createUserWithRole('Adviser');

        $missingAdviserStudent = $this->createUserWithRole('Student', 'Missing Adviser');
        $assignedStudent = $this->createUserWithRole('Student', 'Assigned Student');
        $this->createUserWithRole('Student', 'Missing Profile');

        $this->createInternshipProfileFor($missingAdviserStudent, $supervisor, 486, 'Acme Corp');
        $assignedProfile = $this->createInternshipProfileFor($assignedStudent, $supervisor, 486, 'Beta LLC');
        $assignedProfile->update([
            'adviser_id' => $adviser->id,
        ]);

        Sanctum::actingAs($admin);

        $response = $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/admin/students?filter=missing_adviser');

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Missing Adviser')
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('meta.last_page', 1);

        $this->assertSame($missingAdviserStudent->id, $response->json('data.0.student_id'));
    }

    public function test_students_endpoint_rejects_invalid_filter(): void
    {
        $admin = $this->createUserWithRole('Admin');

        Sanctum::actingAs($admin);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/admin/students?filter=unknown')
            ->assertStatus(422)
            ->assertJsonPath('message', 'Validation failed.')
            ->assertJsonStructure([
                'data' => [
                    'errors' => [
                        'filter',
                    ],
                ],
            ]);
    }

    public function test_students_endpoint_returns_empty_payload_when_student_role_is_missing(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $this->createUserWithRole('Supervisor', 'Non Student User');

        Sanctum::actingAs($admin);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/admin/students?per_page=20')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertExactJson([
                'success' => true,
                'message' => 'Admin students retrieved successfully.',
                'data' => [],
                'meta' => [
                    'current_page' => 1,
                    'per_page' => 20,
                    'total' => 0,
                    'last_page' => 1,
                    'has_more_pages' => false,
                ],
            ]);
    }

    public function test_students_endpoint_rejects_invalid_page_size(): void
    {
        $admin = $this->createUserWithRole('Admin');

        Sanctum::actingAs($admin);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/admin/students?per_page=9')
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

    public function test_non_admin_cannot_retrieve_students_listing(): void
    {
        $student = $this->createUserWithRole('Student');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/admin/students')
            ->assertForbidden()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Only admins can access students list.');
    }

    private function createUserWithRole(string $roleName, ?string $name = null): User
    {
        return User::factory()->create([
            'name' => $name ?? "{$roleName} User",
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
        ]);
    }

    private function createInternshipProfileFor(
        User $student,
        ?User $supervisor = null,
        int $requiredHours = 486,
        string $companyName = 'Acme Corp'
    ): InternshipProfile {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor?->id,
            'company_name' => $companyName,
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
