<?php

namespace Database\Factories;

use App\Models\LogEntry;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<LogEntry>
 */
class LogEntryFactory extends Factory
{
    protected $model = LogEntry::class;

    public function definition(): array
    {
        return [
            'internship_profile_id' => 1,
            'date' => fake()->date(),
            'hours_rendered' => fake()->numberBetween(1, 12),
            'date' => fake()->dateTimeBetween('-30 days', 'now')->format('Y-m-d'),
            'hours_rendered' => fake()->numberBetween(1, 8),
            'task_description' => fake()->sentence(),
            'status' => 'PENDING',
            'submitted_at' => now(),
        ];
    }
}
