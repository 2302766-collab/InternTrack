<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('log_entries')) {
            return;
        }

        if (!$this->hasIndexForColumns('log_entries', ['internship_profile_id'])) {
            Schema::table('log_entries', function (Blueprint $table) {
                $table->index('internship_profile_id');
            });
        }

        if ($this->hasIndex('log_entries', 'log_entries_internship_profile_id_date_unique')) {
            Schema::table('log_entries', function (Blueprint $table) {
                $table->dropUnique('log_entries_internship_profile_id_date_unique');
            });
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('log_entries')) {
            return;
        }

        if (!$this->hasIndex('log_entries', 'log_entries_internship_profile_id_date_unique')) {
            Schema::table('log_entries', function (Blueprint $table) {
                $table->unique(['internship_profile_id', 'date']);
            });
        }

        if ($this->hasIndex('log_entries', 'log_entries_internship_profile_id_index')) {
            Schema::table('log_entries', function (Blueprint $table) {
                $table->dropIndex('log_entries_internship_profile_id_index');
            });
        }
    }

    private function hasIndex(string $table, string $indexName): bool
    {
        $connection = Schema::getConnection();
        $schema = $connection->getSchemaBuilder();

        if (method_exists($schema, 'getIndexes')) {
            foreach ($schema->getIndexes($table) as $index) {
                if (($index['name'] ?? null) === $indexName) {
                    return true;
                }
            }
        }

        $driver = $connection->getDriverName();

        if ($driver === 'sqlite') {
            return collect(DB::select("PRAGMA index_list('{$table}')"))
                ->contains(fn ($index) => ($index->name ?? null) === $indexName);
        }

        if (in_array($driver, ['mysql', 'mariadb'], true)) {
            return collect(DB::select("SHOW INDEX FROM {$table} WHERE Key_name = ?", [$indexName]))
                ->isNotEmpty();
        }

        if ($driver === 'pgsql') {
            return collect(DB::select(
                'select indexname from pg_indexes where tablename = ? and indexname = ?',
                [$table, $indexName],
            ))->isNotEmpty();
        }

        if ($driver === 'sqlsrv') {
            return collect(DB::select(
                'select name from sys.indexes where object_id = object_id(?) and name = ?',
                [$table, $indexName],
            ))->isNotEmpty();
        }

        return false;
    }

    private function hasIndexForColumns(string $table, array $columns): bool
    {
        $schema = Schema::getConnection()->getSchemaBuilder();

        if (!method_exists($schema, 'getIndexes')) {
            return false;
        }

        foreach ($schema->getIndexes($table) as $index) {
            if (($index['columns'] ?? []) === $columns) {
                return true;
            }
        }

        return false;
    }
};
