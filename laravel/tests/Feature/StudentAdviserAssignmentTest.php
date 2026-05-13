<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class StudentAdviserAssignmentTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $student;
    private User $adviser;

    protected function setUp(): void
    {
        parent::setUp();

        // Create roles
        $adminRole = Role::create(['name' => 'Admin']);
        $studentRole = Role::create(['name' => 'Student']);
        $adviserRole = Role::create(['name' => 'Adviser']);

        // Create users
        $this->admin = User::create([
            'name' => 'Admin User',
            'email' => 'admin@test.com',
            'password' => 'password',
            'role_id' => $adminRole->id,
        ]);

        $this->student = User::create([
            'name' => 'John Doe',
            'email' => 'student@test.com',
            'password' => 'password',
            'role_id' => $studentRole->id,
        ]);

        $this->adviser = User::create([
            'name' => 'Jane Smith',
            'email' => 'adviser@test.com',
            'password' => 'password',
            'role_id' => $adviserRole->id,
        ]);
    }

    #[Test]
    public function admin_can_assign_adviser_to_student()
    {
        $response = $this->actingAs($this->admin, 'sanctum')
            ->patchJson('/api/v1/admin/students/' . $this->student->id . '/assign-adviser', [
                'adviser_id' => $this->adviser->id,
            ]);

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'success',
            'message',
            'data' => [
                'student_id',
                'student_name',
                'adviser_id',
                'adviser_name',
                'assigned_at',
            ],
        ]);

        // Verify in database
        $profile = InternshipProfile::where('student_id', $this->student->id)->first();
        $this->assertNotNull($profile);
        $this->assertEquals($this->adviser->id, $profile->adviser_id);
    }

    #[Test]
    public function admin_can_remove_adviser_from_student()
    {
        // First assign
        InternshipProfile::create([
            'student_id' => $this->student->id,
            'adviser_id' => $this->adviser->id,
            'company_name' => 'Test Company',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->toDateString(),
            'end_date' => now()->addMonths(3)->toDateString(),
        ]);

        $response = $this->actingAs($this->admin, 'sanctum')
            ->patchJson('/api/v1/admin/students/' . $this->student->id . '/assign-adviser', [
                'adviser_id' => null,
            ]);

        $response->assertStatus(200);
        $response->assertJson([
            'success' => true,
            'message' => 'Adviser assignment removed successfully.',
        ]);

        // Verify in database
        $profile = InternshipProfile::where('student_id', $this->student->id)->first();
        $this->assertNull($profile->adviser_id);
    }

    #[Test]
    public function admin_gets_404_when_student_not_found()
    {
        $response = $this->actingAs($this->admin, 'sanctum')
            ->patchJson('/api/v1/admin/students/99999/assign-adviser', [
                'adviser_id' => $this->adviser->id,
            ]);

        $response->assertStatus(404);
        $response->assertJson([
            'success' => false,
            'message' => 'Student not found.',
        ]);
    }

    #[Test]
    public function admin_gets_400_when_assigning_non_adviser_user()
    {
        $nonAdviser = User::create([
            'name' => 'Not an Adviser',
            'email' => 'notadviser@test.com',
            'password' => 'password',
            'role_id' => Role::where('name', 'Student')->first()->id,
        ]);

        $response = $this->actingAs($this->admin, 'sanctum')
            ->patchJson('/api/v1/admin/students/' . $this->student->id . '/assign-adviser', [
                'adviser_id' => $nonAdviser->id,
            ]);

        $response->assertStatus(400);
        $response->assertJson([
            'success' => false,
            'message' => 'Selected user is not an adviser.',
        ]);
    }

    #[Test]
    public function admin_can_change_adviser()
    {
        // Create another adviser
        $adviser2 = User::create([
            'name' => 'Bob Johnson',
            'email' => 'adviser2@test.com',
            'password' => 'password',
            'role_id' => Role::where('name', 'Adviser')->first()->id,
        ]);

        // First assignment
        $this->actingAs($this->admin, 'sanctum')
            ->patchJson('/api/v1/admin/students/' . $this->student->id . '/assign-adviser', [
                'adviser_id' => $this->adviser->id,
            ]);

        // Change adviser
        $response = $this->actingAs($this->admin, 'sanctum')
            ->patchJson('/api/v1/admin/students/' . $this->student->id . '/assign-adviser', [
                'adviser_id' => $adviser2->id,
            ]);

        $response->assertStatus(200);
        $response->assertJson([
            'success' => true,
            'message' => 'Adviser assigned successfully.',
            'data' => [
                'adviser_id' => $adviser2->id,
                'adviser_name' => 'Bob Johnson',
            ],
        ]);

        // Verify in database
        $profile = InternshipProfile::where('student_id', $this->student->id)->first();
        $this->assertEquals($adviser2->id, $profile->adviser_id);
    }

    #[Test]
    public function admin_can_get_student_adviser_info()
    {
        // Assign adviser
        InternshipProfile::create([
            'student_id' => $this->student->id,
            'adviser_id' => $this->adviser->id,
            'company_name' => 'Test Company',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->toDateString(),
            'end_date' => now()->addMonths(3)->toDateString(),
        ]);

        $response = $this->actingAs($this->admin, 'sanctum')
            ->getJson('/api/v1/admin/students/' . $this->student->id . '/adviser');

        $response->assertStatus(200);
        $response->assertJson([
            'success' => true,
            'data' => [
                'student_id' => $this->student->id,
                'student_name' => 'John Doe',
                'adviser_id' => $this->adviser->id,
                'adviser_name' => 'Jane Smith',
            ],
        ]);
    }

    #[Test]
    public function admin_can_get_all_advisers()
    {
        $adviser2 = User::create([
            'name' => 'Bob Johnson',
            'email' => 'adviser2@test.com',
            'password' => 'password',
            'role_id' => Role::where('name', 'Adviser')->first()->id,
        ]);

        $response = $this->actingAs($this->admin, 'sanctum')
            ->getJson('/api/v1/admin/advisers');

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'success',
            'message',
            'data' => [
                '*' => ['id', 'name', 'email'],
            ],
        ]);

        $response->assertJsonCount(2, 'data');
    }

    #[Test]
    public function non_admin_cannot_assign_adviser()
    {
        $response = $this->actingAs($this->student, 'sanctum')
            ->patchJson('/api/v1/admin/students/' . $this->student->id . '/assign-adviser', [
                'adviser_id' => $this->adviser->id,
            ]);

        $response->assertStatus(403);
    }

    #[Test]
    public function unauthenticated_user_cannot_assign_adviser()
    {
        $response = $this->patchJson('/api/v1/admin/students/' . $this->student->id . '/assign-adviser', [
            'adviser_id' => $this->adviser->id,
        ]);

        $response->assertStatus(401);
    }

    #[Test]
    public function adviser_id_must_be_integer()
    {
        $response = $this->actingAs($this->admin, 'sanctum')
            ->patchJson('/api/v1/admin/students/' . $this->student->id . '/assign-adviser', [
                'adviser_id' => 'not-an-integer',
            ]);

        $response->assertStatus(422);
    }
}
