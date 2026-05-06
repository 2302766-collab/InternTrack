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
            $table->string('company_address')->nullable()->change();
            $table->unsignedInteger('required_hours')->default(0)->change();
            $table->date('start_date')->nullable()->change();
            $table->date('end_date')->nullable()->change();
        });
    }

    public function down(): void
    {
        $today = now()->toDateString();

        DB::table('internship_profiles')
            ->whereNull('company_address')
            ->update(['company_address' => '']);

        DB::table('internship_profiles')
            ->whereNull('required_hours')
            ->update(['required_hours' => 0]);

        DB::table('internship_profiles')
            ->whereNull('start_date')
            ->update(['start_date' => $today]);

        DB::table('internship_profiles')
            ->whereNull('end_date')
            ->update(['end_date' => $today]);

        Schema::table('internship_profiles', function (Blueprint $table) {
            $table->string('company_address')->nullable(false)->change();
            $table->unsignedInteger('required_hours')->default(null)->change();
            $table->date('start_date')->nullable(false)->change();
            $table->date('end_date')->nullable(false)->change();
        });
    }
};
