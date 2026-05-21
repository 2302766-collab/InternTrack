<?php

namespace Tests\Unit;

use App\Models\InternshipProfile;
use App\Services\AdviserAlertService;
use Carbon\Carbon;
use PHPUnit\Framework\TestCase;
use stdClass;

class AdviserAlertServiceTest extends TestCase
{
    private AdviserAlertService $service;

    protected function setUp(): void
    {
        parent::setUp();

        $this->service = new AdviserAlertService();
    }

    public function test_no_logs_active_internship_returns_no_logs_yet(): void
    {
        $alert = $this->service->evaluate(
            $this->profile(),
            $this->summary(totalLogs: 0),
            Carbon::parse('2026-04-20')
        );

        $this->assertSame('NO_LOGS_YET', $alert['status']);
        $this->assertSame('2026-04-20', $alert['meta']['server_date']);
    }

    public function test_recent_logs_and_reasonable_progress_returns_on_track(): void
    {
        $alert = $this->service->evaluate(
            $this->profile(requiredHours: 160),
            $this->summary(completedHours: 80, totalLogs: 1, lastLogDate: '2026-04-20'),
            Carbon::parse('2026-04-20')
        );

        $this->assertSame('ON_TRACK', $alert['status']);
        $this->assertSame('success', $alert['severity']);
    }

    public function test_inactive_beyond_working_day_threshold_returns_inactive(): void
    {
        $alert = $this->service->evaluate(
            $this->profile(requiredHours: 160),
            $this->summary(completedHours: 90, totalLogs: 1, lastLogDate: '2026-04-14'),
            Carbon::parse('2026-04-20')
        );

        $this->assertSame('INACTIVE', $alert['status']);
        $this->assertSame(4, $alert['meta']['inactive_working_days']);
    }

    public function test_early_stage_student_is_not_marked_behind(): void
    {
        $alert = $this->service->evaluate(
            $this->profile(requiredHours: 160),
            $this->summary(completedHours: 1, totalLogs: 1, lastLogDate: '2026-04-08'),
            Carbon::parse('2026-04-08')
        );

        $this->assertSame('ON_TRACK', $alert['status']);
        $this->assertSame(3, $alert['meta']['elapsed_working_days']);
    }

    public function test_insufficient_progress_relative_to_timeline_returns_behind(): void
    {
        $alert = $this->service->evaluate(
            $this->profile(requiredHours: 160),
            $this->summary(completedHours: 40, totalLogs: 1, lastLogDate: '2026-04-20'),
            Carbon::parse('2026-04-20')
        );

        $this->assertSame('BEHIND', $alert['status']);
        $this->assertSame(88.0, $alert['meta']['expected_hours_by_now']);
    }

    public function test_future_internship_is_not_flagged(): void
    {
        $alert = $this->service->evaluate(
            $this->profile(
                startDate: '2026-04-27',
                endDate: '2026-05-22',
                requiredHours: 160
            ),
            $this->summary(totalLogs: 0),
            Carbon::parse('2026-04-20')
        );

        $this->assertSame('ON_TRACK', $alert['status']);
        $this->assertSame('Internship has not started yet.', $alert['message']);
    }

    private function profile(
        string $startDate = '2026-04-06',
        string $endDate = '2026-05-01',
        int $requiredHours = 160,
        ?int $supervisorId = 1
    ): InternshipProfile {
        return new InternshipProfile([
            'required_hours' => $requiredHours,
            'start_date' => $startDate,
            'end_date' => $endDate,
            'supervisor_id' => $supervisorId,
        ]);
    }

    private function summary(
        int $completedHours = 0,
        int $totalLogs = 0,
        ?string $lastLogDate = null
    ): stdClass {
        return (object) [
            'completed_hours' => $completedHours,
            'total_logs' => $totalLogs,
            'last_log_date' => $lastLogDate,
        ];
    }
}
