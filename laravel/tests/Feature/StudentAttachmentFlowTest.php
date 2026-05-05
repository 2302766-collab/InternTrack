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

class StudentAttachmentFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_student_can_list_only_owned_logs_with_attachment_metadata(): void
    {
        $owner = $this->createStudent();
        $ownerProfile = $this->createInternshipProfileFor($owner);
        $olderLog = $this->createLogEntryFor($ownerProfile, 'PENDING', now()->subDays(1)->toDateString());
        $newerLog = $this->createLogEntryFor($ownerProfile, 'PENDING', now()->toDateString());

        Attachment::create([
            'log_entry_id' => $newerLog->id,
            'file_path' => "log_attachments/{$owner->id}/{$newerLog->id}/proof.jpg",
            'file_type' => 'jpg',
            'file_size' => 120000,
        ]);

        $otherStudent = $this->createStudent();
        $otherProfile = $this->createInternshipProfileFor($otherStudent);
        $this->createLogEntryFor($otherProfile, 'PENDING');

        Sanctum::actingAs($owner);

        $response = $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/logs');

        $response
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Logs retrieved successfully.')
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $newerLog->id)
            ->assertJsonPath('data.0.attachments_count', 1)
            ->assertJsonPath('data.0.has_attachments', true)
            ->assertJsonPath('data.1.id', $olderLog->id)
            ->assertJsonPath('data.1.attachments_count', 0)
            ->assertJsonPath('data.1.has_attachments', false);
    }

    public function test_log_listing_fails_without_internship_profile(): void
    {
        $student = $this->createStudent();
        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/logs')
            ->assertNotFound()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'No internship profile found for this student.');
    }

    public function test_student_can_upload_jpg_attachment_to_pending_log(): void
    {
        Storage::fake('local');

        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $log = $this->createLogEntryFor($profile);

        Sanctum::actingAs($student);

        $file = UploadedFile::fake()->create('proof.jpg', 120, 'image/jpeg');

        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ]);

        $response
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Attachment uploaded successfully.')
            ->assertJsonPath('data.file_type', 'jpg');

        $filePath = $response->json('data.file_path');
        $this->assertStringStartsWith("log_attachments/{$student->id}/{$log->id}/", $filePath);
        Storage::disk('local')->assertExists($filePath);

        $this->assertDatabaseHas('attachments', [
            'log_entry_id' => $log->id,
            'file_path' => $filePath,
            'file_type' => 'jpg',
            'file_size' => $file->getSize(),
        ]);
    }

    public function test_student_can_upload_pdf_attachment_to_pending_log(): void
    {
        Storage::fake('local');

        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $log = $this->createLogEntryFor($profile);

        Sanctum::actingAs($student);

        $file = UploadedFile::fake()->create('proof.pdf', 256, 'application/pdf');

        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ]);

        $response
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Attachment uploaded successfully.')
            ->assertJsonPath('data.file_type', 'pdf');

        $filePath = $response->json('data.file_path');
        $this->assertStringStartsWith("log_attachments/{$student->id}/{$log->id}/", $filePath);
        Storage::disk('local')->assertExists($filePath);

        $this->assertDatabaseHas('attachments', [
            'log_entry_id' => $log->id,
            'file_path' => $filePath,
            'file_type' => 'pdf',
            'file_size' => $file->getSize(),
        ]);
    }

    public function test_attachment_upload_fails_when_log_already_has_proof(): void
    {
        Storage::fake('local');

        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $log = $this->createLogEntryFor($profile);

        Attachment::create([
            'log_entry_id' => $log->id,
            'file_path' => "log_attachments/{$student->id}/{$log->id}/existing-proof.jpg",
            'file_type' => 'jpg',
            'file_size' => 120000,
        ]);

        Sanctum::actingAs($student);

        $file = UploadedFile::fake()->create('another-proof.pdf', 100, 'application/pdf');

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ])
            ->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'A proof attachment already exists for this log.');
    }

    public function test_attachment_upload_fails_for_unsupported_file_type(): void
    {
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $log = $this->createLogEntryFor($profile);

        Sanctum::actingAs($student);

        $file = UploadedFile::fake()->create('malware.exe', 100, 'application/octet-stream');

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ])
            ->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Validation failed.')
            ->assertJsonPath('data.errors.file.0', 'Invalid file type. Only jpg, jpeg, png, and pdf are allowed.');
    }

    public function test_student_can_upload_jpeg_attachment_to_pending_log(): void
    {
        Storage::fake('local');

        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $log = $this->createLogEntryFor($profile);

        Sanctum::actingAs($student);

        $file = UploadedFile::fake()->create('proof.jpeg', 100, 'image/jpeg');

        $response = $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ])
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Attachment uploaded successfully.')
            ->assertJsonPath('data.file_type', 'jpg');

        $filePath = $response->json('data.file_path');
        $this->assertStringStartsWith("log_attachments/{$student->id}/{$log->id}/", $filePath);
        Storage::disk('local')->assertExists($filePath);

        $this->assertDatabaseHas('attachments', [
            'log_entry_id' => $log->id,
            'file_path' => $filePath,
            'file_type' => 'jpg',
            'file_size' => $file->getSize(),
        ]);
    }

    public function test_attachment_upload_fails_when_file_exceeds_5mb(): void
    {
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $log = $this->createLogEntryFor($profile);

        Sanctum::actingAs($student);

        $file = UploadedFile::fake()->create('large.pdf', 5201, 'application/pdf');

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ])
            ->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'File too large. Maximum size is 5MB.')
            ->assertJsonPath('data.errors.file.0', 'File too large. Maximum size is 5MB.');
    }

    public function test_attachment_upload_fails_for_non_existent_log(): void
    {
        $student = $this->createStudent();
        $this->createInternshipProfileFor($student);

        Sanctum::actingAs($student);

        $file = UploadedFile::fake()->create('proof.pdf', 100, 'application/pdf');

        $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/student/logs/999999/attachments', [
                'file' => $file,
            ])
            ->assertNotFound()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Log not found.');
    }

    public function test_attachment_upload_fails_for_log_not_owned_by_student(): void
    {
        $owner = $this->createStudent();
        $ownerProfile = $this->createInternshipProfileFor($owner);
        $log = $this->createLogEntryFor($ownerProfile);

        $otherStudent = $this->createStudent();
        $this->createInternshipProfileFor($otherStudent);
        Sanctum::actingAs($otherStudent);

        $file = UploadedFile::fake()->create('proof.pdf', 100, 'application/pdf');

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ])
            ->assertForbidden()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'You are not allowed to upload attachment to this log.');
    }

    public function test_attachment_upload_fails_for_approved_log(): void
    {
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $log = $this->createLogEntryFor($profile, 'APPROVED');

        Sanctum::actingAs($student);

        $file = UploadedFile::fake()->create('proof.pdf', 100, 'application/pdf');

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ])
            ->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Attachments can only be added to PENDING logs.');
    }

    public function test_attachment_upload_fails_for_rejected_log(): void
    {
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student);
        $log = $this->createLogEntryFor($profile, 'REJECTED');

        Sanctum::actingAs($student);

        $file = UploadedFile::fake()->create('proof.pdf', 100, 'application/pdf');

        $this->withHeader('Accept', 'application/json')
            ->post("/api/v1/student/logs/{$log->id}/attachments", [
                'file' => $file,
            ])
            ->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Attachments can only be added to PENDING logs.');
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
        string $status = 'PENDING',
        ?string $date = null
    ): LogEntry
    {
        return LogEntry::create([
            'internship_profile_id' => $profile->id,
            'date' => $date ?? now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Worked on internship tasks.',
            'status' => $status,
            'submitted_at' => now(),
        ]);
    }
}
