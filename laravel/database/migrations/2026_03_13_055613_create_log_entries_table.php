<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('log_entries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('internship_profile_id')->constrained('internship_profiles')->onDelete('cascade');
            $table->date('date');
            $table->unsignedTinyInteger('hours_rendered');
            $table->text('task_description');
            $table->string('status')->default('PENDING');
            $table->timestamp('submitted_at')->nullable();
            $table->timestamps();

            $table->unique(['internship_profile_id', 'date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('log_entries');
    }
};
