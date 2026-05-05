<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('log_actions', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('log_entry_id');
            $table->unsignedBigInteger('supervisor_id');
            $table->string('action', 32);
            $table->text('comment')->nullable();
            $table->timestamp('acted_at');
            $table->timestamps();

            $table->foreign('log_entry_id')->references('id')->on('log_entries')->onDelete('cascade');
            $table->foreign('supervisor_id')->references('id')->on('users')->onDelete('cascade');
            $table->index(['log_entry_id', 'action']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('log_actions');
    }
};
