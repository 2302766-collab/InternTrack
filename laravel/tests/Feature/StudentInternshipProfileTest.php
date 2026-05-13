<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class StudentInternshipProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_student_can_fetch_supervisor_list(): void
    {
        $student = $this->createUserWithRole('Student');
        $supervisorA = $this->createUserWithRole('Supervisor');
        $supervisorB = $this->createUserWithRole('Supervisor');
        $this->createUserWithRole('Adviser');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/supervisors')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonCount(2, 'data')
            ->assertJsonFragment(['id' => $supervisorA->id, 'role' => 'Supervisor'])
            ->assertJsonFragment(['id' => $supervisorB->id, 'role' => 'Supervisor']);
    }

    public function test_student_can_create_internship_profile_with_supervisor_assignment(): void
    {
        $student = $this->createUserWithRole('Student');
        $supervisor = $this->createUserWithRole('Supervisor');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/student/internship', [
                'company_name' => 'Acme Corp',
                'company_address' => '123 Main St',
                'supervisor_id' => $supervisor->id,
                'required_hours' => 486,
                'start_date' => now()->subDays(5)->toDateString(),
                'end_date' => now()->addDays(30)->toDateString(),
            ])
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.student_id', $student->id)
            ->assertJsonPath('data.supervisor_id', $supervisor->id);
    }

    public function test_student_cannot_create_internship_profile_with_non_supervisor_assignment(): void
    {
        $student = $this->createUserWithRole('Student');
        $adviser = $this->createUserWithRole('Adviser');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/student/internship', [
                'company_name' => 'Acme Corp',
                'company_address' => '123 Main St',
                'supervisor_id' => $adviser->id,
                'required_hours' => 486,
                'start_date' => now()->subDays(5)->toDateString(),
                'end_date' => now()->addDays(30)->toDateString(),
            ])
            ->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Validation failed.');
    }

    public function test_student_can_update_internship_profile_without_changing_supervisor(): void
    {
        $student = $this->createUserWithRole('Student');
        $supervisor = $this->createUserWithRole('Supervisor');
        $profile = $this->helperInternshipProfileFor($student, $supervisor, [
            'company_name' => 'Old Co',
            'company_address' => 'Old Addr',
        ]);

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->patchJson('/api/v1/student/internship', [
                'company_name' => 'New Co',
                'company_address' => 'New Addr',
                'required_hours' => 500,
                'start_date' => now()->subDays(3)->toDateString(),
                'end_date' => now()->addDays(40)->toDateString(),
            ])
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.company_name', 'New Co')
            ->assertJsonPath('data.supervisor_id', $supervisor->id);

        $profile->refresh();
        $this->assertSame('New Co', $profile->company_name);
        $this->assertSame(500, (int) $profile->required_hours);
    }

    public function test_student_update_internship_profile_rejects_end_on_or_before_start(): void
    {
        $student = $this->createUserWithRole('Student');
        $supervisor = $this->createUserWithRole('Supervisor');
        $this->helperInternshipProfileFor($student, $supervisor);

        Sanctum::actingAs($student);

        $start = now()->addDays(10)->toDateString();

        $this->withHeader('Accept', 'application/json')
            ->patchJson('/api/v1/student/internship', [
                'company_name' => 'Acme Corp',
                'company_address' => '123 Main St',
                'required_hours' => 100,
                'start_date' => $start,
                'end_date' => $start,
            ])
            ->assertStatus(422)
            ->assertJsonPath('success', false);
    }

    private function createUserWithRole(string $roleName): User
    {
        return User::factory()->create([
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
        ]);
    }
}
