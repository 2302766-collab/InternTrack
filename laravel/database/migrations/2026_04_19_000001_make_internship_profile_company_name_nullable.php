<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('internship_profiles', function (Blueprint $table) {
            $table->string('company_name')->nullable()->change();
        });
    }

    public function down(): void
    {
        DB::table('internship_profiles')
            ->whereNull('company_name')
            ->update(['company_name' => '']);

        Schema::table('internship_profiles', function (Blueprint $table) {
            $table->string('company_name')->nullable(false)->change();
        });
    }
};
