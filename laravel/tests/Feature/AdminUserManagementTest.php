<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminUserManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_list_managed_users(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $student = $this->createUserWithRole('Student', 'Managed Student');
        $adviser = $this->createUserWithRole('Adviser', 'Managed Adviser');
        $supervisor = $this->createUserWithRole('Supervisor', 'Managed Supervisor');
        $this->createUserWithRole('Admin', 'Other Admin');

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/v1/admin/users');

        $response
            ->assertOk()
            ->assertJsonPath('message', 'Managed users retrieved successfully.')
            ->assertJsonCount(3, 'data')
            ->assertJsonFragment([
                'id' => $student->id,
                'name' => 'Managed Student',
                'role' => 'Student',
            ])
            ->assertJsonFragment([
                'id' => $adviser->id,
                'name' => 'Managed Adviser',
                'role' => 'Adviser',
            ])
            ->assertJsonFragment([
                'id' => $supervisor->id,
                'name' => 'Managed Supervisor',
                'role' => 'Supervisor',
            ]);
    }

    public function test_admin_can_create_managed_user(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $this->helperRole('Adviser');

        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/v1/admin/users', [
            'name' => '  <b>Jane Adviser</b>  ',
            'email' => 'JANE.ADVISER@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'Adviser',
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('message', 'Adviser account created successfully.')
            ->assertJsonPath('data.name', 'Jane Adviser')
            ->assertJsonPath('data.email', 'jane.adviser@example.com')
            ->assertJsonPath('data.role', 'Adviser');

        $this->assertDatabaseHas('users', [
            'email' => 'jane.adviser@example.com',
        ]);
    }

    public function test_admin_can_delete_student_and_related_records_are_removed(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $student = $this->createUserWithRole('Student', 'Delete Me Student');
        $supervisor = $this->createUserWithRole('Supervisor');

        $profile = InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor->id,
            'company_name' => 'Delete Co',
            'company_address' => 'Delete Street',
            'required_hours' => 486,
            'start_date' => now()->subWeek()->toDateString(),
            'end_date' => now()->addWeek()->toDateString(),
        ]);

        $dtr = \App\Models\DailyTimeRecord::create([
            'student_id' => $student->id,
            'date' => now()->toDateString(),
            'time_in' => '08:00:00',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->deleteJson("/api/v1/admin/users/{$student->id}");

        $response
            ->assertOk()
            ->assertJsonPath('message', 'Student account removed successfully.')
            ->assertJsonPath('data.id', $student->id);

        $this->assertDatabaseMissing('users', ['id' => $student->id]);
        $this->assertDatabaseMissing('internship_profiles', ['id' => $profile->id]);
        $this->assertDatabaseMissing('daily_time_records', ['id' => $dtr->id]);
    }

    public function test_admin_can_delete_supervisor_and_assignments_are_cleared(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $student = $this->createUserWithRole('Student');
        $supervisor = $this->createUserWithRole('Supervisor', 'Remove Supervisor');

        $profile = InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor->id,
            'company_name' => 'Acme Corp',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->subWeek()->toDateString(),
            'end_date' => now()->addWeek()->toDateString(),
        ]);

        Sanctum::actingAs($admin);

        $response = $this->deleteJson("/api/v1/admin/users/{$supervisor->id}");

        $response
            ->assertOk()
            ->assertJsonPath('message', 'Supervisor account removed successfully.');

        $this->assertDatabaseMissing('users', ['id' => $supervisor->id]);
        $this->assertNull($profile->fresh()->supervisor_id);
    }

    public function test_admin_cannot_create_admin_account_through_managed_user_endpoint(): void
    {
        $admin = $this->createUserWithRole('Admin');

        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/v1/admin/users', [
            'name' => 'Blocked Admin',
            'email' => 'blocked-admin@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'Admin',
        ]);

        $response->assertUnprocessable();
        $this->assertDatabaseMissing('users', [
            'email' => 'blocked-admin@example.com',
        ]);
    }

    public function test_admin_cannot_delete_admin_account_through_managed_user_endpoint(): void
    {
        $admin = $this->createUserWithRole('Admin');
        $otherAdmin = $this->createUserWithRole('Admin', 'Protected Admin');

        Sanctum::actingAs($admin);

        $response = $this->deleteJson("/api/v1/admin/users/{$otherAdmin->id}");

        $response
            ->assertUnprocessable()
            ->assertJsonPath(
                'message',
                'Only student, adviser, and supervisor accounts can be removed here.'
            );

        $this->assertDatabaseHas('users', ['id' => $otherAdmin->id]);
    }

    public function test_non_admin_cannot_manage_users(): void
    {
        $student = $this->createUserWithRole('Student');

        Sanctum::actingAs($student);

        $this->getJson('/api/v1/admin/users')->assertForbidden();
        $this->postJson('/api/v1/admin/users', [
            'name' => 'Blocked User',
            'email' => 'blocked-user@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'Student',
        ])->assertForbidden();
        $this->deleteJson('/api/v1/admin/users/1')->assertForbidden();
    }

    private function createUserWithRole(string $roleName, ?string $name = null): User
    {
        return User::factory()->create([
            'name' => $name ?? "{$roleName} User",
            'role_id' => $this->helperRole($roleName)->id,
        ]);
    }
}
