<?php

namespace Database\Seeders;

use App\Models\InternshipProfile;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Seeder;

class InternshipProfileSeeder extends Seeder
{
    public function run(): void
    {
        $student = User::where('email', 'student@example.com')->first();
        $supervisor = User::where('email', 'supervisor@example.com')->first();
        $adviser = User::where('email', 'adviser@example.com')->first();

        if (!$student || !$supervisor) {
            $this->command?->warn('Seed users not found; skipping internship profile seeding.');
            return;
        }

        $profile = InternshipProfile::firstOrCreate(
            ['student_id' => $student->id],
            [
                'company_name' => 'Acme Innovations',
                'company_address' => '123 Tech Park, City',
                'required_hours' => 486,
                'start_date' => Carbon::today()->subDays(10)->toDateString(),
                'end_date' => Carbon::today()->addMonths(3)->toDateString(),
                'supervisor_id' => $supervisor->id,
                'adviser_id' => $adviser?->id,
            ],
        );

        $this->command?->info(
            sprintf(
                'Internship profile seeded for %s (supervisor: %s).',
                $student->email,
                $supervisor->email
            )
        );
    }
}
