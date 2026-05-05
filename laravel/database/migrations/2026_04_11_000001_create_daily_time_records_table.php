<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('daily_time_records', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained('users')->cascadeOnDelete();
            $table->date('date');
            $table->timestamp('time_in_at')->nullable();
            $table->timestamp('lunch_out_at')->nullable();
            $table->timestamp('lunch_in_at')->nullable();
            $table->timestamp('time_out_at')->nullable();
            $table->unsignedInteger('first_work_minutes')->default(0);
            $table->unsignedInteger('second_work_minutes')->default(0);
            $table->unsignedInteger('total_work_minutes')->default(0);
            $table->string('status')->default('NOT_STARTED');
            $table->timestamps();

            $table->unique(['student_id', 'date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('daily_time_records');
    }
};
