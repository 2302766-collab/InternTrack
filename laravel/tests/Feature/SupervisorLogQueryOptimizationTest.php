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

        // Create roles
        $supervisorRole = Role::create(['name' => 'Supervisor']);
        $studentRole = Role::create(['name' => 'Student']);

        // Create users
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

        // Create internship profile
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
        // Create multiple log entries to test N+1 scenario
        $logs = LogEntry::factory()
            ->count(10)
            ->create([
                'internship_profile_id' => $this->profile->id,
                'status' => 'PENDING',
            ]);

        // Enable query logging
        DB::enableQueryLog();

        // Make the request
        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->getJson('/api/v1/supervisor/logs');

        // Get query count
        $queries = DB::getQueryLog();
        $queryCount = count($queries);

        // Disable query logging
        DB::disableQueryLog();

        // Assertions
        $response->assertStatus(200);
        $response->assertJsonCount(10, 'data');

        // Verify query count is reasonable and constant (no N+1 growth).
        $this->assertLessThanOrEqual(7, $queryCount, 
            "Query count should be ≤7, but was {$queryCount}. Queries: " . 
            implode(', ', array_column($queries, 'query'))
        );

        // Verify the response structure
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
        // Create a log entry
        $log = LogEntry::factory()->create([
            'internship_profile_id' => $this->profile->id,
            'status' => 'PENDING',
        ]);

        // Enable query logging
        DB::enableQueryLog();

        // Make the request
        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->getJson("/api/v1/supervisor/logs/{$log->id}");

        // Get query count
        $queries = DB::getQueryLog();
        $queryCount = count($queries);

        // Disable query logging
        DB::disableQueryLog();

        // Assertions
        $response->assertStatus(200);

        // Verify query count is reasonable and constant (no N+1 growth).
        $this->assertLessThanOrEqual(6, $queryCount, 
            "Query count should be ≤6, but was {$queryCount}. Queries: " . 
            implode(', ', array_column($queries, 'query'))
        );
    }

    #[Test]
    public function empty_log_list_uses_minimal_queries()
    {
        // Enable query logging
        DB::enableQueryLog();

        // Make the request with no logs
        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->getJson('/api/v1/supervisor/logs');

        // Get query count
        $queries = DB::getQueryLog();
        $queryCount = count($queries);

        // Disable query logging
        DB::disableQueryLog();

        // Assertions
        $response->assertStatus(200);
        $response->assertJsonCount(0, 'data');

        // Should use minimal queries for empty result
        $this->assertLessThanOrEqual(3, $queryCount, 
            "Empty list should use ≤3 queries, but was {$queryCount}"
        );
    }

    #[Test]
    public function large_dataset_performance_test()
    {
        // Create a larger dataset (50 logs)
        $logs = LogEntry::factory()
            ->count(50)
            ->create([
                'internship_profile_id' => $this->profile->id,
                'status' => 'PENDING',
            ]);

        // Enable query logging
        DB::enableQueryLog();

        // Make the request
        $response = $this->actingAs($this->supervisor, 'sanctum')
            ->getJson('/api/v1/supervisor/logs');

        // Get query count
        $queries = DB::getQueryLog();
        $queryCount = count($queries);

        // Disable query logging
        DB::disableQueryLog();

        // Assertions
        $response->assertStatus(200);
        $response->assertJsonCount(50, 'data');

        // Query count should remain constant regardless of dataset size.
        $this->assertLessThanOrEqual(7, $queryCount, 
            "Query count should be ≤7 even with 50 logs, but was {$queryCount}"
        );
    }
}
