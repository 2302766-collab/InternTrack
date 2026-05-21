<?php

namespace Tests\Feature;

use App\Models\DailyTimeRecord;
use App\Models\EditRequest;
use App\Models\Notification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EditRequestWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_student_can_request_log_edit_and_admin_can_approve_it(): void
    {
        $student = $this->helperStudent();
        $supervisor = $this->helperSupervisor();
        $admin = $this->helperAdmin();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'APPROVED', now()->subDay()->toDateString(), [
            'hours_rendered' => 8,
            'task_description' => 'Original task details',
        ]);

        Sanctum::actingAs($student);

        $this->postJson("/api/v1/student/logs/{$log->id}/edit-request", [
            'date' => now()->subDay()->toDateString(),
            'hours_rendered' => 6,
            'task_description' => 'Corrected task details',
            'reason' => 'Wrong hours and incomplete task description.',
        ])
            ->assertCreated()
            ->assertJsonPath('data.resource_type', 'LOG')
            ->assertJsonPath('data.status', 'PENDING');

        $editRequest = EditRequest::query()->firstOrFail();
        $this->assertSame(EditRequest::RESOURCE_LOG, $editRequest->resource_type);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $admin->id,
            'type' => 'EDIT_REQUEST_SUBMITTED',
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $supervisor->id,
            'type' => 'EDIT_REQUEST_SUBMITTED',
        ]);

        Sanctum::actingAs($admin);

        $this->patchJson("/api/v1/admin/edit-requests/{$editRequest->id}/approve", [
            'comment' => 'Approved after checking the correction.',
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'APPROVED');

        $this->assertDatabaseHas('edit_requests', [
            'id' => $editRequest->id,
            'status' => 'APPROVED',
            'reviewer_id' => $admin->id,
        ]);
        $this->assertDatabaseHas('log_entries', [
            'id' => $log->id,
            'hours_rendered' => 6,
            'task_description' => 'Corrected task details',
            'status' => 'APPROVED',
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $student->id,
            'type' => 'EDIT_REQUEST_APPROVED',
        ]);
    }

    public function test_student_can_request_dtr_edit_and_admin_can_reject_it(): void
    {
        $student = $this->helperStudent();
        $supervisor = $this->helperSupervisor();
        $admin = $this->helperAdmin();
        $this->helperInternshipProfileFor($student, $supervisor);

        $record = DailyTimeRecord::query()->create([
            'student_id' => $student->id,
            'date' => now()->toDateString(),
            'time_in_at' => now()->startOfDay()->addHours(8),
            'lunch_out_at' => now()->startOfDay()->addHours(12),
            'lunch_in_at' => now()->startOfDay()->addHours(13),
            'time_out_at' => now()->startOfDay()->addHours(17),
            'first_work_minutes' => 240,
            'second_work_minutes' => 240,
            'total_work_minutes' => 480,
            'status' => 'COMPLETED',
        ]);

        Sanctum::actingAs($student);

        $this->postJson('/api/v1/student/dtr/edit-request', [
            'date' => now()->toDateString(),
            'daily_time_record_id' => $record->id,
            'time_in_at' => now()->startOfDay()->addHours(8)->addMinutes(15)->toIso8601String(),
            'lunch_out_at' => now()->startOfDay()->addHours(12)->toIso8601String(),
            'lunch_in_at' => now()->startOfDay()->addHours(13)->toIso8601String(),
            'time_out_at' => now()->startOfDay()->addHours(17)->toIso8601String(),
            'reason' => 'I forgot to time in exactly at 8:15 AM.',
        ])
            ->assertCreated()
            ->assertJsonPath('data.resource_type', 'DTR')
            ->assertJsonPath('data.status', 'PENDING');

        $editRequest = EditRequest::query()->firstOrFail();

        Sanctum::actingAs($admin);

        $this->patchJson("/api/v1/admin/edit-requests/{$editRequest->id}/reject", [
            'comment' => 'Please attach supporting proof before resubmitting.',
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'REJECTED');

        $record->refresh();
        $this->assertSame(480, $record->total_work_minutes);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $student->id,
            'type' => 'EDIT_REQUEST_REJECTED',
        ]);
    }

    public function test_supervisor_can_approve_assigned_student_edit_request(): void
    {
        $student = $this->helperStudent();
        $supervisor = $this->helperSupervisor();
        $this->helperInternshipProfileFor($student, $supervisor);

        Sanctum::actingAs($student);

        $requestDate = now()->subDays(2)->startOfDay();

        $this->postJson('/api/v1/student/dtr/edit-request', [
            'date' => $requestDate->toDateString(),
            'time_in_at' => $requestDate->copy()->addHours(8)->toIso8601String(),
            'lunch_out_at' => $requestDate->copy()->addHours(12)->toIso8601String(),
            'lunch_in_at' => $requestDate->copy()->addHours(13)->toIso8601String(),
            'time_out_at' => $requestDate->copy()->addHours(17)->toIso8601String(),
            'reason' => 'I forgot to punch for the full day even though I was present.',
        ])->assertCreated();

        $editRequest = EditRequest::query()->firstOrFail();

        $this->assertDatabaseHas('notifications', [
            'user_id' => $supervisor->id,
            'type' => 'EDIT_REQUEST_SUBMITTED',
        ]);

        Sanctum::actingAs($supervisor);

        $this->getJson('/api/v1/supervisor/edit-requests')
            ->assertOk()
            ->assertJsonPath('data.0.id', $editRequest->id);

        $this->patchJson("/api/v1/supervisor/edit-requests/{$editRequest->id}/approve", [
            'comment' => 'Attendance matches the submitted explanation.',
        ])
            ->assertOk()
            ->assertJsonPath('data.status', 'APPROVED');

        $record = DailyTimeRecord::query()->findOrFail($editRequest->daily_time_record_id);

        $this->assertSame('COMPLETED', $record->status);
        $this->assertSame(480, $record->total_work_minutes);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $student->id,
            'type' => 'EDIT_REQUEST_APPROVED',
        ]);
    }

    private function helperAdmin(array $overrides = [])
    {
        return $this->helperUserForRole('Admin', $overrides);
    }

    private function helperUserForRole(string $role, array $overrides = [])
    {
        return \App\Models\User::factory()->create(array_merge([
            'role_id' => $this->helperRole($role)->id,
        ], $overrides));
    }
}
