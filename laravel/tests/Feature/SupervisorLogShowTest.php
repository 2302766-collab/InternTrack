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

class SupervisorLogShowTest extends TestCase
{
    use RefreshDatabase;

    public function test_supervisor_can_view_assigned_log_with_attachments(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile);

        $attachment = Attachment::create([
            'log_entry_id' => $log->id,
            'file_path' => 'log_attachments/sample.pdf',
            'file_type' => 'pdf',
            'file_size' => 12345,
        ]);

        LogAction::create([
            'log_entry_id' => $log->id,
            'supervisor_id' => $supervisor->id,
            'action' => 'REJECTED',
            'comment' => 'Please add more detail to the task description.',
            'acted_at' => now(),
        ]);

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/supervisor/logs/{$log->id}")
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Log retrieved successfully.')
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    'id',
                    'internship_profile_id',
                    'student' => [
                        'name',
                        'email',
                    ],
                    'company_name',
                    'date',
                    'hours_rendered',
                    'task_description',
                    'status',
                    'submitted_at',
                    'attachments' => [
                        [
                            'id',
                            'file_path',
                            'file_type',
                            'file_size',
                            'created_at',
                        ],
                    ],
                    'review_history' => [
                        [
                            'id',
                            'action',
                            'comment',
                            'acted_at',
                            'supervisor' => [
                                'id',
                                'name',
                                'email',
                            ],
                        ],
                    ],
                ],
            ])
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
            ->assertJsonPath('data.attachments.0.file_path', 'log_attachments/sample.pdf')
            ->assertJsonPath('data.attachments.0.file_type', 'pdf')
            ->assertJsonPath('data.attachments.0.file_size', 12345)
            ->assertJsonPath('data.review_history.0.action', 'REJECTED')
            ->assertJsonPath('data.review_history.0.comment', 'Please add more detail to the task description.');
    }

    public function test_supervisor_can_view_assigned_log_when_company_name_is_missing(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor, null);
        $log = $this->createLogEntryFor($profile);

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/supervisor/logs/{$log->id}")
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.company_name', null)
            ->assertJsonPath('data.student.name', $student->name)
            ->assertJsonPath('data.student.email', $student->email);
    }

    public function test_supervisor_can_view_assigned_logs_regardless_of_status(): void
    {
        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);

        foreach (['PENDING', 'APPROVED', 'REJECTED'] as $status) {
            $log = $this->createLogEntryFor($profile, $status);

            Sanctum::actingAs($supervisor);

            $this->withHeader('Accept', 'application/json')
                ->get("/api/v1/supervisor/logs/{$log->id}")
                ->assertOk()
                ->assertJsonPath('success', true)
                ->assertJsonPath('data.status', $status);
        }
    }

    public function test_supervisor_cannot_view_unassigned_log(): void
    {
        $supervisor = $this->createSupervisor();
        $otherSupervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $otherSupervisor);
        $log = $this->createLogEntryFor($profile);

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/supervisor/logs/{$log->id}")
            ->assertStatus(403)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'You are not allowed to access this log.');
    }

    public function test_unauthenticated_request_cannot_view_log(): void
    {
        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/logs/1')
            ->assertUnauthorized()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Unauthenticated.')
            ->assertJsonPath('data', null);
    }

    public function test_non_supervisor_cannot_view_log(): void
    {
        $student = $this->createStudent();
        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/logs/1')
            ->assertStatus(403)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Forbidden: insufficient role.')
            ->assertJsonPath('data', null);
    }

    public function test_missing_log_returns_404(): void
    {
        $supervisor = $this->createSupervisor();
        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/supervisor/logs/999999')
            ->assertNotFound()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Log not found.');
    }

    public function test_supervisor_can_download_attachment_for_assigned_log(): void
    {
        Storage::fake('local');

        $supervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $supervisor);
        $log = $this->createLogEntryFor($profile);

        Storage::disk('local')->put(
            'log_attachments/sample-proof.jpg',
            'fake-image-binary'
        );

        $attachment = Attachment::create([
            'log_entry_id' => $log->id,
            'file_path' => 'log_attachments/sample-proof.jpg',
            'file_type' => 'jpg',
            'file_size' => 17,
        ]);

        Sanctum::actingAs($supervisor);

        $response = $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/supervisor/logs/{$log->id}/attachments/{$attachment->id}");

        $response->assertOk();
        $response->assertHeader('content-type', 'image/jpeg');
    }

    public function test_supervisor_cannot_download_attachment_for_unassigned_log(): void
    {
        Storage::fake('local');

        $supervisor = $this->createSupervisor();
        $otherSupervisor = $this->createSupervisor();
        $student = $this->createStudent();
        $profile = $this->createInternshipProfileFor($student, $otherSupervisor);
        $log = $this->createLogEntryFor($profile);

        Storage::disk('local')->put(
            'log_attachments/unassigned-proof.jpg',
            'fake-image-binary'
        );

        $attachment = Attachment::create([
            'log_entry_id' => $log->id,
            'file_path' => 'log_attachments/unassigned-proof.jpg',
            'file_type' => 'jpg',
            'file_size' => 17,
        ]);

        Sanctum::actingAs($supervisor);

        $this->withHeader('Accept', 'application/json')
            ->get("/api/v1/supervisor/logs/{$log->id}/attachments/{$attachment->id}")
            ->assertForbidden()
            ->assertJsonPath('message', 'You are not allowed to access this log attachment.');
    }

    private function createRole(string $name): Role
    {
        return Role::query()->firstOrCreate(['name' => $name]);
    }

    private function createSupervisor(): User
    {
        return User::factory()->create([
            'role_id' => $this->createRole('Supervisor')->id,
        ]);
    }

    private function createStudent(): User
    {
        return User::factory()->create([
            'role_id' => $this->createRole('Student')->id,
        ]);
    }

    private function createInternshipProfileFor(
        User $student,
        User $supervisor,
        ?string $companyName = 'Acme Corp'
    ): InternshipProfile
    {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor->id,
            'company_name' => $companyName,
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->subDays(5)->toDateString(),
            'end_date' => now()->addDays(30)->toDateString(),
        ]);
    }

    private function createLogEntryFor(
        InternshipProfile $profile,
        string $status = 'PENDING'
    ): LogEntry {
        return LogEntry::create([
            'internship_profile_id' => $profile->id,
            'date' => now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Reviewed project updates.',
            'status' => $status,
            'submitted_at' => now(),
        ]);
    }
}
