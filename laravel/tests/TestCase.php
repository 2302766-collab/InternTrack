<?php

namespace Tests;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;
use RuntimeException;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        $this->guardAgainstUnsafeTestingDatabase();
    }

    private function guardAgainstUnsafeTestingDatabase(): void
    {
        if (! app()->environment('testing')) {
            return;
        }

        $connection = config('database.default');
        $configuredDatabase = (string) config("database.connections.{$connection}.database", '');
        $actualDatabase = (string) DB::connection($connection)->getDatabaseName();

        if ($this->isSafeTestingDatabase($configuredDatabase) && $this->isSafeTestingDatabase($actualDatabase)) {
            return;
        }

        throw new RuntimeException(sprintf(
            'Refusing to run tests on non-test database. Connection [%s] is configured for [%s] and connected to [%s].',
            $connection,
            $configuredDatabase,
            $actualDatabase,
        ));
    }

    private function isSafeTestingDatabase(string $database): bool
    {
        return $database === ':memory:'
            || str_ends_with($database, '_test')
            || str_contains($database, '_testing');
    }

    protected function helperRole(string $name): Role
    {
        return Role::query()->firstOrCreate(['name' => $name]);
    }

    protected function helperSupervisor(array $overrides = []): User
    {
        return User::factory()->create(array_merge([
            'role_id' => $this->helperRole('Supervisor')->id,
        ], $overrides));
    }

    protected function helperStudent(array $overrides = []): User
    {
        return User::factory()->create(array_merge([
            'role_id' => $this->helperRole('Student')->id,
        ], $overrides));
    }

    protected function helperAdviser(array $overrides = []): User
    {
        return User::factory()->create(array_merge([
            'role_id' => $this->helperRole('Adviser')->id,
        ], $overrides));
    }

    protected function helperInternshipProfileFor(
        User $student,
        ?User $supervisor = null,
        array $overrides = []
    ): InternshipProfile {
        return InternshipProfile::create(array_merge([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor?->id,
            'company_name' => 'Acme Corp',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => now()->subDays(5)->toDateString(),
            'end_date' => now()->addDays(30)->toDateString(),
        ], $overrides));
    }

    protected function helperLogEntryFor(
        InternshipProfile $profile,
        string $status = 'PENDING',
        ?string $date = null,
        array $overrides = []
    ): LogEntry {
        return LogEntry::create(array_merge([
            'internship_profile_id' => $profile->id,
            'date' => $date ?? now()->toDateString(),
            'hours_rendered' => 8,
            'task_description' => 'Reviewed project updates.',
            'status' => $status,
            'submitted_at' => now(),
        ], $overrides));
    }
}
