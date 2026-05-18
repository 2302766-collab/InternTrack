<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('edit_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('requester_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('reviewer_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('resource_type', 16);
            $table->foreignId('log_entry_id')->nullable()->constrained('log_entries')->cascadeOnDelete();
            $table->foreignId('daily_time_record_id')->nullable()->constrained('daily_time_records')->cascadeOnDelete();
            $table->string('status', 16)->default('PENDING');
            $table->text('reason');
            $table->json('requested_changes');
            $table->text('review_comment')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'resource_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('edit_requests');
    }
};
