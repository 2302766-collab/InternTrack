<?php

namespace Tests\Feature;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class SupervisorLogQueryOptimizationTest extends TestCase
{
    use RefreshDatabase;

    private User $supervisor;
    private User $student;
    private InternshipProfile $profile;

    protected function setUp(): void
    {
        parent::setUp();

        $supervisorRole = Role::create(['name' => 'Supervisor']);
        $studentRole = Role::create(['name' => 'Student']);

        $this->supervisor = User::create([
            'name' => 'Test Supervisor',
            'email' => 'supervisor@test.com',
            'password' => 'password',
            'role_id' => $supervisorRole->id,
        ]);

        $this->student = User::create([
            'name' => 'Test Student',
            'email' => 'student@test.com',
            'password' => 'password',
            'role_id' => $studentRole->id,
        ]);

        $this->profile = InternshipProfile::create([
            'student_id' => $this->student->id,
            'supervisor_id' => $this->supervisor->id,
            'company_name' => 'Test Company',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->subDays(7)->toDateString(),
            'end_date' => now()->addMonths(3)->toDateString(),
        ]);
    }

    #[Test]
    public function supervisor_log_listing_uses_eager_loading_to_prevent_n_plus_one_queries()
    {
        LogEntry::factory()
            ->count(10)
            ->create([
                'internship_profile_id' => $this->profile->id,
                'status' => 'PENDING',
            ]);

        DB::enableQueryLog();

        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->getJson('/api/v1/supervisor/logs');

        $queries = DB::getQueryLog();
        $queryCount = count($queries);

        DB::disableQueryLog();

        $response->assertStatus(200);
        $response->assertJsonCount(10, 'data');

        $this->assertLessThanOrEqual(
            7,
            $queryCount,
            "Query count should be <=7, but was {$queryCount}. Queries: " .
                implode(', ', array_column($queries, 'query'))
        );

        $response->assertJsonStructure([
            'success',
            'message',
            'data' => [
                '*' => [
                    'id',
                    'internship_profile_id',
                    'student_name',
                    'date',
                    'hours_rendered',
                    'task_description',
                    'status',
                    'submitted_at',
                    'attachments_count',
                    'has_attachments',
                ],
            ],
        ]);
    }

    #[Test]
    public function supervisor_log_show_uses_eager_loading_to_prevent_n_plus_one_queries()
    {
        $log = LogEntry::factory()->create([
            'internship_profile_id' => $this->profile->id,
            'status' => 'PENDING',
        ]);

        DB::enableQueryLog();

        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->getJson("/api/v1/supervisor/logs/{$log->id}");

        $queries = DB::getQueryLog();
        $queryCount = count($queries);

        DB::disableQueryLog();

        $response->assertStatus(200);

        $this->assertLessThanOrEqual(
            6,
            $queryCount,
            "Query count should be <=6, but was {$queryCount}. Queries: " .
                implode(', ', array_column($queries, 'query'))
        );
    }

    #[Test]
    public function empty_log_list_uses_minimal_queries()
    {
        DB::enableQueryLog();

        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->getJson('/api/v1/supervisor/logs');

        $queries = DB::getQueryLog();
        $queryCount = count($queries);

        DB::disableQueryLog();

        $response->assertStatus(200);
        $response->assertJsonCount(0, 'data');

        $this->assertLessThanOrEqual(
            3,
            $queryCount,
            "Empty list should use <=3 queries, but was {$queryCount}"
        );
    }

    #[Test]
    public function large_dataset_performance_test()
    {
        LogEntry::factory()
            ->count(50)
            ->create([
                'internship_profile_id' => $this->profile->id,
                'status' => 'PENDING',
            ]);

        DB::enableQueryLog();

        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->getJson('/api/v1/supervisor/logs');

        $queries = DB::getQueryLog();
        $queryCount = count($queries);

        DB::disableQueryLog();

        $response->assertStatus(200);
        $response->assertJsonCount(50, 'data');

        $this->assertLessThanOrEqual(
            7,
            $queryCount,
            "Query count should be <=7 even with 50 logs, but was {$queryCount}"
        );
    }
}
