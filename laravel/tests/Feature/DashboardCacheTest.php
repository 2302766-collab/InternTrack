<?php

namespace Tests\Feature;

use App\Models\LogAction;
use App\Models\User;
use App\Services\DashboardCacheService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DashboardCacheTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow('2026-05-08 10:00:00');
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_supervisor_dashboard_repeat_request_uses_cached_response(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);

        $this->helperLogEntryFor($profile, 'PENDING');

        LogAction::create([
            'log_entry_id' => $this->helperLogEntryFor($profile, 'APPROVED')->id,
            'supervisor_id' => $supervisor->id,
            'action' => 'APPROVED',
            'comment' => 'Looks good.',
            'acted_at' => now(),
        ]);

        Sanctum::actingAs($supervisor);

        $cache = app(DashboardCacheService::class);
        $cacheKey = $cache->supervisorDashboardKey($supervisor->id);
        Cache::forget($cacheKey);

        $connection = DB::connection();
        $connection->flushQueryLog();
        $connection->enableQueryLog();

        $this->getJson('/api/v1/supervisor/dashboard')
            ->assertOk()
            ->assertJsonPath('data.pending_review', 1)
            ->assertJsonPath('data.approved_today', 1);

        $firstDashboardQueries = $this->filterDashboardQueries(
            $connection->getQueryLog(),
            ['internship_profiles', 'log_entries', 'log_actions'],
        );

        $this->assertNotEmpty($firstDashboardQueries);
        $this->assertTrue(Cache::has($cacheKey));

        $connection->flushQueryLog();

        $this->getJson('/api/v1/supervisor/dashboard')->assertOk();

        $secondDashboardQueries = $this->filterDashboardQueries(
            $connection->getQueryLog(),
            ['internship_profiles', 'log_entries', 'log_actions'],
        );

        $connection->disableQueryLog();

        $this->assertCount(0, $secondDashboardQueries);
    }

    public function test_supervisor_dashboard_cache_is_invalidated_after_log_approval(): void
    {
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor);
        $log = $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($supervisor);

        $this->getJson('/api/v1/supervisor/dashboard')
            ->assertOk()
            ->assertJsonPath('data.pending_review', 1)
            ->assertJsonPath('data.approved_today', 0);

        $this->postJson("/api/v1/supervisor/logs/{$log->id}/approve", [
            'comment' => 'Great progress.',
        ])->assertOk();

        $this->getJson('/api/v1/supervisor/dashboard')
            ->assertOk()
            ->assertJsonPath('data.pending_review', 0)
            ->assertJsonPath('data.approved_today', 1)
            ->assertJsonPath('data.total_students', 1);
    }

    public function test_supervisor_dashboard_cache_is_invalidated_after_profile_creation(): void
    {
        $supervisor = $this->helperSupervisor();

        Sanctum::actingAs($supervisor);

        $this->getJson('/api/v1/supervisor/dashboard')
            ->assertOk()
            ->assertJsonPath('data.total_students', 0);

        $student = $this->helperStudent();
        $this->helperInternshipProfileFor($student, $supervisor);

        $this->getJson('/api/v1/supervisor/dashboard')
            ->assertOk()
            ->assertJsonPath('data.total_students', 1);
    }

    public function test_admin_dashboard_repeat_request_uses_cached_response(): void
    {
        $admin = $this->createAdmin();
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor, [
            'required_hours' => 40,
        ]);

        $this->helperLogEntryFor($profile, 'APPROVED', overrides: [
            'hours_rendered' => 8,
            'date' => '2026-05-07',
        ]);
        $this->helperLogEntryFor($profile, 'PENDING');

        Sanctum::actingAs($admin);

        $cache = app(DashboardCacheService::class);
        $cacheKey = $cache->adminDashboardKey('2026-05');
        Cache::forget($cacheKey);

        $connection = DB::connection();
        $connection->flushQueryLog();
        $connection->enableQueryLog();

        $this->getJson('/api/v1/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('data.total_students', 1)
            ->assertJsonPath('data.pending_logs', 1)
            ->assertJsonPath('data.approved_logs', 1)
            ->assertJsonPath('data.average_completion_percentage', 20);

        $firstDashboardQueries = $this->filterDashboardQueries(
            $connection->getQueryLog(),
            ['users', 'internship_profiles', 'log_entries'],
        );

        $this->assertNotEmpty($firstDashboardQueries);
        $this->assertTrue(Cache::has($cacheKey));

        $connection->flushQueryLog();

        $this->getJson('/api/v1/admin/dashboard')->assertOk();

        $secondDashboardQueries = $this->filterDashboardQueries(
            $connection->getQueryLog(),
            ['users', 'internship_profiles', 'log_entries'],
        );

        $connection->disableQueryLog();

        $this->assertCount(0, $secondDashboardQueries);
    }

    public function test_admin_dashboard_cache_is_invalidated_after_student_creation(): void
    {
        $admin = $this->createAdmin();

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('data.total_students', 0);

        $this->helperStudent();

        $this->getJson('/api/v1/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('data.total_students', 1);
    }

    public function test_admin_dashboard_cache_is_invalidated_after_log_status_change(): void
    {
        $admin = $this->createAdmin();
        $supervisor = $this->helperSupervisor();
        $student = $this->helperStudent();
        $profile = $this->helperInternshipProfileFor($student, $supervisor, [
            'required_hours' => 40,
        ]);
        $log = $this->helperLogEntryFor($profile, 'PENDING', overrides: [
            'hours_rendered' => 8,
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/v1/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('data.pending_logs', 1)
            ->assertJsonPath('data.approved_logs', 0)
            ->assertJsonPath('data.average_completion_percentage', 0);

        $log->update([
            'status' => 'APPROVED',
        ]);

        $this->getJson('/api/v1/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('data.pending_logs', 0)
            ->assertJsonPath('data.approved_logs', 1)
            ->assertJsonPath('data.average_completion_percentage', 20);
    }

    private function createAdmin(): User
    {
        return User::factory()->create([
            'role_id' => $this->helperRole('Admin')->id,
        ]);
    }

    private function filterDashboardQueries(array $queries, array $tableNames): array
    {
        return array_values(array_filter($queries, function (array $query) use ($tableNames): bool {
            $sql = strtolower($query['query'] ?? '');

            foreach ($tableNames as $tableName) {
                if (str_contains($sql, strtolower($tableName))) {
                    return true;
                }
            }

            return false;
        }));
    }
}
