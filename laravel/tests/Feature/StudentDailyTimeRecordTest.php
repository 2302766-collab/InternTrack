<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class StudentDailyTimeRecordTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_student_sees_not_started_state_when_no_record_exists_for_today(): void
    {
        $student = $this->createUserWithRole('Student');

        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/dtr/today')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'NOT_STARTED')
            ->assertJsonPath('data.current_state_label', 'Not Started')
            ->assertJsonPath('data.next_action', 'TIME_IN')
            ->assertJsonPath('data.total_work_minutes', 0);
    }

    public function test_student_can_complete_the_full_daily_time_record_flow(): void
    {
        $student = $this->createUserWithRole('Student');

        Sanctum::actingAs($student);

        Carbon::setTestNow('2026-04-11 08:00:00');
        $this->postJson('/api/v1/student/dtr/time-in')
            ->assertCreated()
            ->assertJsonPath('data.status', 'WORKING')
            ->assertJsonPath('data.next_action', 'LUNCH_OUT');

        Carbon::setTestNow('2026-04-11 12:30:00');
        $this->postJson('/api/v1/student/dtr/lunch-out')
            ->assertOk()
            ->assertJsonPath('data.status', 'ON_BREAK')
            ->assertJsonPath('data.first_work_minutes', 270)
            ->assertJsonPath('data.total_work_minutes', 270)
            ->assertJsonPath('data.next_action', 'LUNCH_IN');

        Carbon::setTestNow('2026-04-11 13:30:00');
        $this->postJson('/api/v1/student/dtr/lunch-in')
            ->assertOk()
            ->assertJsonPath('data.status', 'WORKING')
            ->assertJsonPath('data.next_action', 'TIME_OUT');

        Carbon::setTestNow('2026-04-11 17:00:00');
        $this->postJson('/api/v1/student/dtr/time-out')
            ->assertOk()
            ->assertJsonPath('data.status', 'COMPLETED')
            ->assertJsonPath('data.second_work_minutes', 210)
            ->assertJsonPath('data.total_work_minutes', 480)
            ->assertJsonPath('data.next_action', null);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/dtr/today')
            ->assertOk()
            ->assertJsonPath('data.status', 'COMPLETED')
            ->assertJsonPath('data.current_state_label', 'Completed')
            ->assertJsonPath('data.first_work_minutes', 270)
            ->assertJsonPath('data.second_work_minutes', 210)
            ->assertJsonPath('data.total_work_minutes', 480);
    }

    public function test_backend_rejects_invalid_sequence_attempts(): void
    {
        $student = $this->createUserWithRole('Student');

        Sanctum::actingAs($student);

        $this->postJson('/api/v1/student/dtr/lunch-out')
            ->assertStatus(409)
            ->assertJsonPath('message', 'Time In must be recorded before Lunch Out.');

        Carbon::setTestNow('2026-04-11 08:15:00');
        $this->postJson('/api/v1/student/dtr/time-in')->assertCreated();

        $this->postJson('/api/v1/student/dtr/time-out')
            ->assertStatus(409)
            ->assertJsonPath('message', 'Lunch In must be recorded before Time Out.');

        $this->postJson('/api/v1/student/dtr/time-in')
            ->assertStatus(409)
            ->assertJsonPath('message', 'Time In has already been recorded for today.');
    }

    public function test_non_student_cannot_access_student_dtr_endpoints(): void
    {
        $admin = $this->createUserWithRole('Admin');

        Sanctum::actingAs($admin);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/dtr/today')
            ->assertForbidden()
            ->assertJsonPath('message', 'Forbidden: insufficient role.');
    }

    private function createUserWithRole(string $roleName): User
    {
        return User::factory()->create([
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
        ]);
    }
}
