<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\InternshipProfile;
use App\Models\LogAction;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdviserLogShowTest extends TestCase
{
    use RefreshDatabase;

    public function test_adviser_can_view_assigned_student_log_with_attachments_and_review_history(): void
    {
        $adviser = $this->createUserWithRole('Adviser');
        $supervisor = $this->createUserWithRole('Supervisor');
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student, $supervisor, $adviser);
        $log = $this->createLogEntryFor($profile);

        $attachment = Attachment::create([
            'log_entry_id' => $log->id,
            'file_path' => 'log_attachments/adviser-sample.pdf',
            'file_type' => 'pdf',
            'file_size' => 12345,
        ]);

        LogAction::create([
            'log_entry_id' => $log->id,
            'supervisor_id' => $supervisor->id,
            'action' => 'APPROVED',
            'comment' => 'Clear and complete work summary.',
            'acted_at' => now(),
        ]);

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/adviser/logs/{$log->id}")
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log retrieved successfully.')
            ->assertJsonPath('data.id', $log->id)
            ->assertJsonPath('data.internship_profile_id', $profile->id)
            ->assertJsonPath('data.student.name', $student->name)
            ->assertJsonPath('data.student.email', $student->email)
            ->assertJsonPath('data.company_name', $profile->company_name)
            ->assertJsonPath('data.date', $log->date)
            ->assertJsonPath('data.hours_rendered', $log->hours_rendered)
            ->assertJsonPath('data.task_description', $log->task_description)
            ->assertJsonPath('data.status', $log->status)
            ->assertJsonPath('data.attachments.0.id', $attachment->id)
            ->assertJsonPath('data.attachments.0.file_path', 'log_attachments/adviser-sample.pdf')
            ->assertJsonPath('data.review_history.0.action', 'APPROVED')
            ->assertJsonPath('data.review_history.0.supervisor.id', $supervisor->id)
            ->assertJsonPath('data.review_history.0.comment', 'Clear and complete work summary.');
    }

    public function test_adviser_cannot_view_unassigned_student_log(): void
    {
        $adviser = $this->createUserWithRole('Adviser');
        $otherAdviser = $this->createUserWithRole('Adviser');
        $supervisor = $this->createUserWithRole('Supervisor');
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student, $supervisor, $otherAdviser);
        $log = $this->createLogEntryFor($profile);

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/adviser/logs/{$log->id}")
            ->assertForbidden()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'You are not allowed to access this log.');
    }

    public function test_missing_adviser_log_returns_404(): void
    {
        $adviser = $this->createUserWithRole('Adviser');
        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/adviser/logs/999999')
            ->assertNotFound()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Log not found.');
    }

    public function test_adviser_can_download_attachment_for_assigned_student_log(): void
    {
        Storage::fake('local');

        $adviser = $this->createUserWithRole('Adviser');
        $supervisor = $this->createUserWithRole('Supervisor');
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student, $supervisor, $adviser);
        $log = $this->createLogEntryFor($profile);

        Storage::disk('local')->put(
            'log_attachments/adviser-proof.png',
            'fake-image-binary'
        );

        $attachment = Attachment::create([
            'log_entry_id' => $log->id,
            'file_path' => 'log_attachments/adviser-proof.png',
            'file_type' => 'png',
            'file_size' => 17,
        ]);

        Sanctum::actingAs($adviser);

        $response = $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/adviser/logs/{$log->id}/attachments/{$attachment->id}");

        $response->assertOk();
        $response->assertHeader('content-type', 'image/png');
    }

    public function test_adviser_cannot_download_attachment_for_unassigned_student_log(): void
    {
        Storage::fake('local');

        $adviser = $this->createUserWithRole('Adviser');
        $otherAdviser = $this->createUserWithRole('Adviser');
        $supervisor = $this->createUserWithRole('Supervisor');
        $student = $this->createUserWithRole('Student');
        $profile = $this->createInternshipProfileFor($student, $supervisor, $otherAdviser);
        $log = $this->createLogEntryFor($profile);

        Storage::disk('local')->put(
            'log_attachments/unassigned-adviser-proof.jpg',
            'fake-image-binary'
        );

        $attachment = Attachment::create([
            'log_entry_id' => $log->id,
            'file_path' => 'log_attachments/unassigned-adviser-proof.jpg',
            'file_type' => 'jpg',
            'file_size' => 17,
        ]);

        Sanctum::actingAs($adviser);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/adviser/logs/{$log->id}/attachments/{$attachment->id}")
            ->assertForbidden()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'You are not allowed to access this log attachment.');
    }

    private function createUserWithRole(string $roleName): User
    {
        return User::factory()->create([
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
        ]);
    }

    private function createInternshipProfileFor(
        User $student,
        User $supervisor,
        User $adviser
    ): InternshipProfile {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor->id,
            'adviser_id' => $adviser->id,
            'company_name' => 'Acme Corp',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->subDays(5)->toDateString(),
            'end_date' => now()->addDays(30)->toDateString(),
        ]);
    }

    private function createLogEntryFor(InternshipProfile $profile): LogEntry
    {
        return LogEntry::create([
            'internship_profile_id' => $profile->id,
            'date' => now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Reviewed project updates.',
            'status' => 'PENDING',
            'submitted_at' => now(),
        ]);
    }
}
