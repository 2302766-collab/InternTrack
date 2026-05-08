<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SecurityHardeningTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test that file upload rate limiting is enforced
     * 10 requests per minute should succeed, 11th should fail
     */
    public function test_file_upload_rate_limiting_enforces_10_requests_per_minute(): void
    {
        Storage::fake('local');

        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student);
        
        Sanctum::actingAs($student);

        // Create 10 logs
        $logs = [];
        for ($i = 0; $i < 10; $i++) {
            $log = $this->helperLogEntryFor($profile, 'PENDING', now()->subDays($i)->toDateString());
            $logs[] = $log;
        }

        // Upload attachments to first 10 logs - should all succeed
        for ($i = 0; $i < 10; $i++) {
            $file = UploadedFile::fake()->create("proof_$i.jpg", 100, 'image/jpeg');
            
            $response = $this->withHeader('Accept', 'application/json')
                ->post("/api/v1/student/logs/{$logs[$i]->id}/attachments", [
                    'file' => $file,
                ]);

            $this->assertLessThan(429, $response->getStatusCode(), 
                "Request $i should not be rate limited");
        }

        // 11th upload should be rate limited (429 Too Many Requests)
        $eleventhLog = $this->helperLogEntryFor($profile, 'PENDING', now()->subDays(10)->toDateString());
        $file = UploadedFile::fake()->create('proof_11.jpg', 100, 'image/jpeg');
        
        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$eleventhLog->id}/attachments", [
                'file' => $file,
            ]);

        $this->assertEquals(429, $response->getStatusCode(), 
            'The 11th request should be rate limited (429 Too Many Requests)');
    }

    /**
     * Test that attachment creation failures return safe error messages
     * without exposing database internals
     */
    public function test_attachment_creation_failure_returns_safe_error_message(): void
    {
        Storage::fake('local');

        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($student);

        // Upload first attachment - should succeed
        $file = UploadedFile::fake()->create('proof.jpg', 100, 'image/jpeg');
        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ]);
        
        $this->assertEquals(201, $response->getStatusCode());

        // Try to upload second attachment - should fail with safe message
        $file = UploadedFile::fake()->create('proof2.jpg', 100, 'image/jpeg');
        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ]);

        $response
            ->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'A proof attachment already exists for this log.');

        // Verify the error message does NOT contain database details
        $responseBody = json_encode($response->json());
        $this->assertStringNotContainsString('SQLSTATE', $responseBody, 
            'Error response should not contain SQL error codes');
        $this->assertStringNotContainsString('CONSTRAINT', $responseBody, 
            'Error response should not contain constraint violations');
        $this->assertStringNotContainsString('constraint violation', $responseBody, 
            'Error response should not expose database constraints');
    }

    /**
     * Test that rejection comments can be up to 2000 characters
     */
    public function test_supervisor_can_reject_log_with_max_2000_character_comment(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        // Create a 2000 character comment
        $maxComment = str_repeat('A', 2000);

        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => $maxComment,
            ]);

        $response
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log rejected successfully.')
            ->assertJsonPath('data.status', 'REJECTED')
            ->assertJsonPath('data.review_history.0.comment', $maxComment);

        $this->assertDatabaseHas('log_actions', [
            'log_entry_id' => $log->id,
            'supervisor_id' => $supervisor->id,
            'action' => 'REJECTED',
            'comment' => $maxComment,
        ]);
    }

    /**
     * Test that rejection comments exceeding 2000 characters are rejected
     */
    public function test_supervisor_cannot_reject_log_with_comment_exceeding_2000_characters(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        // Create a 2001 character comment (1 too many)
        $tooLongComment = str_repeat('A', 2001);

        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/reject", [
                'comment' => $tooLongComment,
            ]);

        $response
            ->assertUnprocessable()
            ->assertJsonPath('success', false)
            ->assertJsonPath('data.errors.comment.0', 'The comment field must not be greater than 2000 characters.');

        $this->assertDatabaseMissing('log_actions', [
            'log_entry_id' => $log->id,
            'action' => 'REJECTED',
        ]);
    }

    /**
     * Test that optional comments in approve can also be up to 2000 characters
     */
    public function test_supervisor_can_approve_log_with_optional_2000_character_comment(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        // Create a 2000 character comment
        $maxComment = str_repeat('B', 2000);

        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/supervisor/logs/{$log->id}/approve", [
                'comment' => $maxComment,
            ]);

        $response
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log approved successfully.')
            ->assertJsonPath('data.status', 'APPROVED')
            ->assertJsonPath('data.review_history.0.comment', $maxComment);

        $this->assertDatabaseHas('log_actions', [
            'log_entry_id' => $log->id,
            'supervisor_id' => $supervisor->id,
            'action' => 'APPROVED',
            'comment' => $maxComment,
        ]);
    }

    /**
     * Test that safe error is returned when database fails during attachment save
     * (e.g., unique constraint violation would normally expose SQL details)
     */
    public function test_attachment_database_error_returns_safe_message_not_sql_details(): void
    {
        Storage::fake('local');

        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        // Pre-create an attachment for this log with the same file_path pattern
        Attachment::create([
            'log_entry_id' => $log->id,
            'file_path' => "log_attachments/{$student->id}/{$log->id}/proof.jpg",
            'file_type' => 'jpg',
            'file_size' => 100000,
        ]);

        Sanctum::actingAs($student);

        // Try to upload when attachment already exists
        $file = UploadedFile::fake()->create('proof.jpg', 100, 'image/jpeg');
        
        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ]);

        // Should return 409 Conflict with safe message
        $response
            ->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'A proof attachment already exists for this log.');

        // Verify safe error format
        $this->assertFalse($response->json('success'));
        $this->assertIsString($response->json('message'));
        $this->assertStringNotContainsString('Exception', json_encode($response->json()),
            'Response should not contain exception class names');
    }

    private function createRole(string $name): Role
    {
        return Role::query()->firstOrCreate(['name' => $name]);
    }

    private function createSupervisor(array $overrides = []): User
    {
        return User::factory()->create(array_merge([
            'role_id' => $this->createRole('Supervisor')->id,
        ], $overrides));
    }

    private function createStudent(array $overrides = []): User
    {
        return User::factory()->create(array_merge([
            'role_id' => $this->createRole('Student')->id,
        ], $overrides));
    }

    private function createInternshipProfileFor(User $student, ?User $supervisor = null): InternshipProfile
    {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor?->id,
            'company_name' => 'Test Company',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->subDays(7)->toDateString(),
            'end_date' => now()->addMonths(3)->toDateString(),
        ]);
    }

    private function createLogEntryFor(
        InternshipProfile $profile,
        string $status = 'PENDING',
        ?string $date = null
    ): LogEntry {
        return LogEntry::create([
            'internship_profile_id' => $profile->id,
            'date' => $date ?? now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Completed assigned tasks',
            'status' => $status,
        ]);
    }
}
