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

    private function createUserWithRole(string $roleName): User
    {
        return User::factory()->create([
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
        ]);
    }
}
