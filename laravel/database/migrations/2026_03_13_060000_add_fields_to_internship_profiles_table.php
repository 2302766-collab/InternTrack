<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('internship_profiles', function (Blueprint $table) {
            $table->foreignId('student_id')
                ->unique()
                ->constrained('users')
                ->cascadeOnDelete();

            $table->string('company_name');
            $table->string('company_address');

            $table->foreignId('supervisor_id')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->foreignId('adviser_id')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->unsignedInteger('required_hours');
            $table->date('start_date');
            $table->date('end_date');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('internship_profiles', function (Blueprint $table) {
            $table->dropUnique('internship_profiles_student_id_unique');
            $table->dropConstrainedForeignId('student_id');
            $table->dropConstrainedForeignId('supervisor_id');
            $table->dropConstrainedForeignId('adviser_id');
            $table->dropColumn([
                'company_name',
                'company_address',
                'required_hours',
                'start_date',
                'end_date',
            ]);
        });
    }
};

