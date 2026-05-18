<?php

namespace Database\Seeders;

use App\Models\DailyTimeRecord;
use App\Models\InternshipProfile;
use App\Models\LogAction;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use App\Services\DashboardCacheService;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class BulkStudentDemoSeeder extends Seeder
{
    private const EMAIL_START = 2;
    private const EMAIL_END = 200;
    private const SUPERVISOR_START = 2;
    private const SUPERVISOR_END = 16;
    private const ADVISER_START = 2;
    private const ADVISER_END = 12;
    private const REQUIRED_HOUR_OPTIONS = [240, 300, 360, 420, 486, 540, 600];

    private const COMPANY_NAMES = [
        'Acme Innovations',
        'Vertex Dynamics',
        'BluePeak Technologies',
        'Northstar Labs',
        'SummitWorks Solutions',
        'Nimbus Systems',
        'CoreBridge Digital',
        'AstraWave Corp',
        'NextField Analytics',
        'Brightline Software',
    ];

    private const TASK_SNIPPETS = [
        'Implemented UI refinements for dashboard widgets',
        'Fixed API integration issues and error handling',
        'Validated submitted records and prepared documentation',
        'Coordinated with supervisor for sprint review actions',
        'Refactored modules and improved maintainability',
        'Tested edge cases for form validation and exports',
        'Reviewed pending logs and updated status notes',
        'Assisted in report generation and data verification',
        'Prepared deployment checklist and release notes',
        'Monitored system behavior and captured findings',
    ];

    public function run(): void
    {
        if (!app()->environment(['local', 'testing'])) {
            $this->command?->warn('BulkStudentDemoSeeder is local/testing only. Skipping.');
            return;
        }

        if (class_exists(\Laravel\Telescope\Telescope::class)) {
            \Laravel\Telescope\Telescope::stopRecording();
        }

        Model::withoutEvents(function (): void {
            $roles = Role::query()->pluck('id', 'name');
            $studentRoleId = $roles['Student'] ?? null;
            $supervisorRoleId = $roles['Supervisor'] ?? null;
            $adviserRoleId = $roles['Adviser'] ?? null;

            if (!$studentRoleId) {
                $this->command?->error('Student role not found. Run RoleSeeder first.');
                return;
            }

            $this->seedReviewers(
                supervisorRoleId: $supervisorRoleId,
                adviserRoleId: $adviserRoleId,
            );

            $supervisorIds = $supervisorRoleId
                ? User::query()->where('role_id', $supervisorRoleId)->pluck('id')->values()->all()
                : [];
            $adviserIds = $adviserRoleId
                ? User::query()->where('role_id', $adviserRoleId)->pluck('id')->values()->all()
                : [];

            $faker = fake();
            $today = Carbon::today();
            $defaultPassword = Hash::make('password');
            $createdUsers = 0;

            for ($i = self::EMAIL_START; $i <= self::EMAIL_END; $i++) {
                $email = "student{$i}@example.com";

                try {
                    DB::transaction(function () use (
                        $faker,
                        $today,
                        $studentRoleId,
                        $supervisorIds,
                        $adviserIds,
                        $defaultPassword,
                        &$createdUsers,
                        $email,
                        $i
                    ): void {
                        $firstName = $faker->firstName();
                        $lastName = $faker->lastName();

                        $student = User::query()->updateOrCreate(
                            ['email' => $email],
                            [
                                'name' => "{$firstName} {$lastName}",
                                'gender' => $faker->randomElement(['Male', 'Female']),
                                'password' => $defaultPassword,
                                'role_id' => $studentRoleId,
                            ],
                        );
                        $createdUsers++;

                        $requiredHours = self::REQUIRED_HOUR_OPTIONS[array_rand(self::REQUIRED_HOUR_OPTIONS)];
                        $startDate = $today->copy()->subDays(random_int(15, 140));
                        $endDate = $startDate->copy()->addDays(random_int(75, 180));
                        $assignedSupervisorId = empty($supervisorIds)
                            ? null
                            : $supervisorIds[($i - self::EMAIL_START) % count($supervisorIds)];
                        $assignedAdviserId = empty($adviserIds)
                            ? null
                            : $adviserIds[($i - self::EMAIL_START) % count($adviserIds)];

                        $profile = InternshipProfile::query()->updateOrCreate(
                            ['student_id' => $student->id],
                            [
                                'company_name' => self::COMPANY_NAMES[array_rand(self::COMPANY_NAMES)] . " {$faker->numberBetween(1, 99)}",
                                'company_address' => $faker->streetAddress() . ', ' . $faker->city(),
                                'required_hours' => $requiredHours,
                                'start_date' => $startDate->toDateString(),
                                'end_date' => $endDate->toDateString(),
                                'supervisor_id' => $assignedSupervisorId,
                                'adviser_id' => $assignedAdviserId,
                            ],
                        );

                        LogEntry::query()->where('internship_profile_id', $profile->id)->delete();
                        DailyTimeRecord::query()->where('student_id', $student->id)->delete();

                        $latestDate = $endDate->isBefore($today) ? $endDate->copy() : $today->copy();
                        $availableDays = max(1, $startDate->diffInDays($latestDate) + 1);
                        $expectedByToday = $this->expectedHoursByToday(
                            requiredHours: $requiredHours,
                            startDate: $startDate,
                            endDate: $endDate,
                            today: $today,
                        );
                        $targets = $this->buildPerformanceTargets(
                            requiredHours: $requiredHours,
                            expectedByToday: $expectedByToday,
                        );

                        $this->seedLogs(
                            profile: $profile,
                            fallbackSupervisorIds: $supervisorIds,
                            startDate: $startDate,
                            availableDays: $availableDays,
                            approvedHoursTarget: $targets['approved_hours_target'],
                            pendingHoursTarget: $targets['pending_hours_target'],
                            rejectedLogsTarget: $targets['rejected_logs_target'],
                        );

                        $this->seedDtr(
                            studentId: $student->id,
                            startDate: $startDate,
                            availableDays: $availableDays,
                        );
                    });
                } catch (\Throwable $exception) {
                    $this->command?->error(sprintf(
                        'Bulk student seed failed for %s: %s',
                        $email,
                        $exception->getMessage(),
                    ));

                    throw $exception;
                }
            }

            $this->command?->info(sprintf(
                'Seeded %d students (%s to %s) with varied internship profiles, logs, and DTR data.',
                $createdUsers,
                'student' . self::EMAIL_START . '@example.com',
                'student' . self::EMAIL_END . '@example.com',
            ));
            $this->command?->line(sprintf(
                'Created/updated supervisors: supervisor%d@example.com to supervisor%d@example.com',
                self::SUPERVISOR_START,
                self::SUPERVISOR_END
            ));
            $this->command?->line(sprintf(
                'Created/updated advisers: adviser%d@example.com to adviser%d@example.com',
                self::ADVISER_START,
                self::ADVISER_END
            ));
            $this->command?->line('Password for all generated students: password');
            $this->command?->line('Password for generated supervisors/advisers: password');

            app(DashboardCacheService::class)->forgetAdminDashboard();
        });
    }

    private function seedReviewers(?int $supervisorRoleId, ?int $adviserRoleId): void
    {
        if ($supervisorRoleId) {
            $defaultPassword = Hash::make('password');

            for ($i = self::SUPERVISOR_START; $i <= self::SUPERVISOR_END; $i++) {
                User::query()->updateOrCreate(
                    ['email' => "supervisor{$i}@example.com"],
                    [
                        'name' => "Supervisor {$i}",
                        'gender' => $i % 2 === 0 ? 'Male' : 'Female',
                        'password' => $defaultPassword,
                        'role_id' => $supervisorRoleId,
                    ],
                );
            }
        }

        if ($adviserRoleId) {
            $defaultPassword = $defaultPassword ?? Hash::make('password');

            for ($i = self::ADVISER_START; $i <= self::ADVISER_END; $i++) {
                User::query()->updateOrCreate(
                    ['email' => "adviser{$i}@example.com"],
                    [
                        'name' => "Adviser {$i}",
                        'gender' => $i % 2 === 0 ? 'Female' : 'Male',
                        'password' => $defaultPassword,
                        'role_id' => $adviserRoleId,
                    ],
                );
            }
        }
    }

    private function seedLogs(
        InternshipProfile $profile,
        array $fallbackSupervisorIds,
        Carbon $startDate,
        int $availableDays,
        int $approvedHoursTarget,
        int $pendingHoursTarget,
        int $rejectedLogsTarget,
    ): void {
        $approvedChunks = $this->splitHoursIntoEntries($approvedHoursTarget);
        $pendingChunks = $this->splitHoursIntoEntries($pendingHoursTarget);

        foreach ($approvedChunks as $hours) {
            $this->createLogEntry(
                profile: $profile,
                status: 'APPROVED',
                hours: $hours,
                startDate: $startDate,
                availableDays: $availableDays,
                fallbackSupervisorIds: $fallbackSupervisorIds,
            );
        }

        foreach ($pendingChunks as $hours) {
            $this->createLogEntry(
                profile: $profile,
                status: 'PENDING',
                hours: $hours,
                startDate: $startDate,
                availableDays: $availableDays,
                fallbackSupervisorIds: $fallbackSupervisorIds,
            );
        }

        for ($i = 0; $i < $rejectedLogsTarget; $i++) {
            $this->createLogEntry(
                profile: $profile,
                status: 'REJECTED',
                hours: random_int(1, 8),
                startDate: $startDate,
                availableDays: $availableDays,
                fallbackSupervisorIds: $fallbackSupervisorIds,
            );
        }
    }

    private function createLogEntry(
        InternshipProfile $profile,
        string $status,
        int $hours,
        Carbon $startDate,
        int $availableDays,
        array $fallbackSupervisorIds,
    ): void {
        $hours = max(1, min($hours, 12));
        $date = $startDate->copy()->addDays(random_int(0, $availableDays - 1));
        $submittedAt = $date->copy()->setTime(random_int(16, 21), random_int(0, 59), random_int(0, 59));

        $log = LogEntry::query()->create([
            'internship_profile_id' => $profile->id,
            'date' => $date->toDateString(),
            'hours_rendered' => $hours,
            'task_description' => self::TASK_SNIPPETS[array_rand(self::TASK_SNIPPETS)] . '.',
            'status' => $status,
            'submitted_at' => $submittedAt,
            'created_at' => $submittedAt,
            'updated_at' => $submittedAt,
        ]);

        if (in_array($status, ['APPROVED', 'REJECTED'], true)) {
            $reviewerId = $profile->supervisor_id;
            if ($reviewerId === null && !empty($fallbackSupervisorIds)) {
                $reviewerId = $fallbackSupervisorIds[array_rand($fallbackSupervisorIds)];
            }
            if ($reviewerId === null) {
                return;
            }

            LogAction::query()->create([
                'log_entry_id' => $log->id,
                'supervisor_id' => $reviewerId,
                'action' => $status,
                'comment' => $status === 'REJECTED'
                    ? 'Please revise formatting and include clearer output evidence.'
                    : 'Reviewed and approved.',
                'acted_at' => $submittedAt->copy()->addHours(random_int(4, 36)),
            ]);
        }
    }

    private function seedDtr(
        int $studentId,
        Carbon $startDate,
        int $availableDays,
    ): void {
        $dtrCount = min($availableDays, random_int(8, 20));
        $dayOffsets = $this->randomUniqueOffsets($availableDays, $dtrCount);

        foreach ($dayOffsets as $offset) {
            $date = $startDate->copy()->addDays($offset);
            $scenario = random_int(1, 4);

            $timeIn = $date->copy()->setTime(random_int(7, 9), random_int(0, 30), 0);
            $lunchOut = $date->copy()->setTime(random_int(11, 13), random_int(0, 30), 0);
            $lunchIn = $lunchOut->copy()->addMinutes(random_int(30, 75));
            $timeOut = $date->copy()->setTime(random_int(16, 19), random_int(0, 30), 0);

            $payload = match ($scenario) {
                1 => $this->completedDtrPayload($timeIn, $lunchOut, $lunchIn, $timeOut),
                2 => $this->onBreakDtrPayload($timeIn, $lunchOut),
                3 => $this->workingAfterLunchDtrPayload($timeIn, $lunchOut, $lunchIn),
                default => $this->notStartedPayload(),
            };

            DailyTimeRecord::query()->create(array_merge(
                ['student_id' => $studentId, 'date' => $date->toDateString()],
                $payload
            ));
        }
    }

    private function completedDtrPayload(Carbon $timeIn, Carbon $lunchOut, Carbon $lunchIn, Carbon $timeOut): array
    {
        $first = max(0, $timeIn->diffInMinutes($lunchOut));
        $second = max(0, $lunchIn->diffInMinutes($timeOut));
        return [
            'time_in_at' => $timeIn,
            'lunch_out_at' => $lunchOut,
            'lunch_in_at' => $lunchIn,
            'time_out_at' => $timeOut,
            'first_work_minutes' => $first,
            'second_work_minutes' => $second,
            'total_work_minutes' => $first + $second,
            'status' => 'COMPLETED',
        ];
    }

    private function onBreakDtrPayload(Carbon $timeIn, Carbon $lunchOut): array
    {
        $first = max(0, $timeIn->diffInMinutes($lunchOut));
        return [
            'time_in_at' => $timeIn,
            'lunch_out_at' => $lunchOut,
            'lunch_in_at' => null,
            'time_out_at' => null,
            'first_work_minutes' => $first,
            'second_work_minutes' => 0,
            'total_work_minutes' => $first,
            'status' => 'ON_BREAK',
        ];
    }

    private function workingAfterLunchDtrPayload(Carbon $timeIn, Carbon $lunchOut, Carbon $lunchIn): array
    {
        $first = max(0, $timeIn->diffInMinutes($lunchOut));
        return [
            'time_in_at' => $timeIn,
            'lunch_out_at' => $lunchOut,
            'lunch_in_at' => $lunchIn,
            'time_out_at' => null,
            'first_work_minutes' => $first,
            'second_work_minutes' => 0,
            'total_work_minutes' => $first,
            'status' => 'WORKING',
        ];
    }

    private function notStartedPayload(): array
    {
        return [
            'time_in_at' => null,
            'lunch_out_at' => null,
            'lunch_in_at' => null,
            'time_out_at' => null,
            'first_work_minutes' => 0,
            'second_work_minutes' => 0,
            'total_work_minutes' => 0,
            'status' => 'NOT_STARTED',
        ];
    }

    private function expectedHoursByToday(
        int $requiredHours,
        Carbon $startDate,
        Carbon $endDate,
        Carbon $today,
    ): int {
        if ($requiredHours <= 0) {
            return 0;
        }

        $start = $startDate->copy()->startOfDay();
        $end = $endDate->copy()->startOfDay();
        $now = $today->copy()->startOfDay();

        if ($now->lt($start)) {
            return 0;
        }

        if ($now->gt($end)) {
            return $requiredHours;
        }

        $totalDays = $start->diffInDays($end) + 1;
        $elapsedDays = $start->diffInDays($now) + 1;
        $expected = (int) round(($requiredHours * $elapsedDays) / max(1, $totalDays));

        return max(0, min($expected, $requiredHours));
    }

    private function buildPerformanceTargets(int $requiredHours, int $expectedByToday): array
    {
        $roll = random_int(1, 100);

        if ($roll <= 70) {
            $approvedTarget = $expectedByToday + random_int(-4, 14);
            $pendingTarget = random_int(2, 18);
            $rejectedTarget = random_int(0, 2);
        } elseif ($roll <= 90) {
            $approvedTarget = $expectedByToday - random_int(30, 120);
            $pendingTarget = random_int(8, 30);
            $rejectedTarget = random_int(1, 4);
        } else {
            $approvedTarget = $expectedByToday + random_int(20, 90);
            $pendingTarget = random_int(0, 12);
            $rejectedTarget = random_int(0, 2);
        }

        $approvedTarget = max(0, min($approvedTarget, $requiredHours));

        return [
            'approved_hours_target' => $approvedTarget,
            'pending_hours_target' => max(0, $pendingTarget),
            'rejected_logs_target' => max(0, $rejectedTarget),
        ];
    }

    private function splitHoursIntoEntries(int $totalHours): array
    {
        $remaining = max(0, $totalHours);
        $chunks = [];

        while ($remaining > 0) {
            if ($remaining <= 12) {
                $chunks[] = $remaining;
                break;
            }

            $chunk = random_int(4, 10);
            $chunks[] = $chunk;
            $remaining -= $chunk;
        }

        return $chunks;
    }

    private function randomUniqueOffsets(int $availableDays, int $count): array
    {
        $count = min(max(0, $count), $availableDays);
        $offsets = [];
        while (count($offsets) < $count) {
            $offsets[random_int(0, $availableDays - 1)] = true;
        }

        $result = array_keys($offsets);
        sort($result);
        return $result;
    }
}
