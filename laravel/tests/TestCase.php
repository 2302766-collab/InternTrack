<?php

namespace Tests;

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
}
