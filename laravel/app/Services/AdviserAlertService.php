<?php

namespace App\Services;

use App\Models\InternshipProfile;
use Carbon\Carbon;
use Carbon\CarbonInterface;

class AdviserAlertService
{
    private const INACTIVE_WORKING_DAYS = 3;
    private const EARLY_STAGE_WORKING_DAYS = 5;
    private const PACE_GRACE_WORKING_DAYS = 2;
    private const NO_LOGS_WARNING_WORKING_DAYS = 5;

    public function evaluate(
        InternshipProfile $profile,
        array|object|null $summary = null,
        ?CarbonInterface $today = null
    ): array {
        $serverDate = $today
            ? Carbon::parse($today->toDateString())->startOfDay()
            : Carbon::today();
        $startDate = $this->parseDate($profile->start_date);
        $endDate = $this->parseDate($profile->end_date);
        $requiredHours = max(0, (int) $profile->required_hours);
        $completedHours = max(0, (int) $this->summaryValue($summary, 'completed_hours', 0));
        $totalLogs = max(0, (int) $this->summaryValue($summary, 'total_logs', 0));
        $lastLogDate = $this->parseDate($this->summaryValue($summary, 'last_log_date'));

        $timeline = $this->timelineMetrics(
            startDate: $startDate,
            endDate: $endDate,
            serverDate: $serverDate,
            requiredHours: $requiredHours
        );
        $inactiveWorkingDays = $this->inactiveWorkingDays(
            startDate: $startDate,
            lastLogDate: $lastLogDate,
            serverDate: $serverDate
        );

        $baseMeta = [
            'server_date' => $serverDate->toDateString(),
            'inactive_threshold_working_days' => self::INACTIVE_WORKING_DAYS,
            'no_logs_warning_working_days' => self::NO_LOGS_WARNING_WORKING_DAYS,
            'inactive_working_days' => $inactiveWorkingDays,
            'completed_hours' => $completedHours,
            'required_hours' => $requiredHours,
            'has_supervisor' => $profile->supervisor_id !== null,
            'completion_percentage' => $requiredHours > 0
                ? round(($completedHours / $requiredHours) * 100, 2)
                : 0,
            ...$timeline,
        ];

        if ($startDate && $serverDate->lt($startDate)) {
            return $this->payload(
                status: 'ON_TRACK',
                message: 'Internship has not started yet.',
                severity: 'info',
                meta: $baseMeta
            );
        }

        if ($profile->supervisor_id === null) {
            return $this->payload(
                status: 'MISSING_SUPERVISOR',
                message: 'No company supervisor has been assigned for this internship yet.',
                severity: 'critical',
                meta: $baseMeta
            );
        }

        if ($totalLogs === 0) {
            $elapsedWorkingDays = (int) ($timeline['elapsed_working_days'] ?? 0);
            $message = $elapsedWorkingDays >= self::NO_LOGS_WARNING_WORKING_DAYS
                ? "No logs submitted after {$elapsedWorkingDays} working days."
                : 'No logs submitted yet for this active internship.';
            $severity = $elapsedWorkingDays >= self::NO_LOGS_WARNING_WORKING_DAYS
                ? 'warning'
                : 'info';

            return $this->payload(
                status: 'NO_LOGS_YET',
                message: $message,
                severity: $severity,
                meta: $baseMeta
            );
        }

        if ($inactiveWorkingDays >= self::INACTIVE_WORKING_DAYS) {
            return $this->payload(
                status: 'INACTIVE',
                message: "No log submitted for {$inactiveWorkingDays} working days.",
                severity: 'critical',
                meta: $baseMeta
            );
        }

        if ($this->isBehindExpectedPace($completedHours, $timeline)) {
            $expectedHours = (int) ceil($timeline['expected_hours_by_now']);

            return $this->payload(
                status: 'BEHIND',
                message: "Behind expected pace. Completed {$completedHours} of {$expectedHours} hours expected by today.",
                severity: 'warning',
                meta: $baseMeta
            );
        }

        return $this->payload(
            status: 'ON_TRACK',
            message: 'Progress is aligned with the internship timeline.',
            severity: 'success',
            meta: $baseMeta
        );
    }

    private function timelineMetrics(
        ?Carbon $startDate,
        ?Carbon $endDate,
        Carbon $serverDate,
        int $requiredHours
    ): array {
        if (!$startDate || !$endDate || $requiredHours <= 0 || $endDate->lt($startDate)) {
            return [
                'total_working_days' => 0,
                'elapsed_working_days' => 0,
                'timeline_percentage' => 0,
                'expected_hours_by_now' => 0,
                'minimum_expected_hours' => 0,
                'early_stage_working_days' => self::EARLY_STAGE_WORKING_DAYS,
                'pace_grace_working_days' => self::PACE_GRACE_WORKING_DAYS,
            ];
        }

        $effectiveDate = $serverDate->gt($endDate) ? $endDate : $serverDate;
        $elapsedWorkingDays = $effectiveDate->lt($startDate)
            ? 0
            : $this->countWorkingDays($startDate, $effectiveDate);
        $totalWorkingDays = max(1, $this->countWorkingDays($startDate, $endDate));
        $dailyExpectedHours = $requiredHours / $totalWorkingDays;
        $expectedHours = $dailyExpectedHours * $elapsedWorkingDays;
        $minimumExpectedHours = max(
            0,
            $expectedHours - ($dailyExpectedHours * self::PACE_GRACE_WORKING_DAYS)
        );

        return [
            'total_working_days' => $totalWorkingDays,
            'elapsed_working_days' => $elapsedWorkingDays,
            'timeline_percentage' => round(($elapsedWorkingDays / $totalWorkingDays) * 100, 2),
            'expected_hours_by_now' => round($expectedHours, 2),
            'minimum_expected_hours' => round($minimumExpectedHours, 2),
            'early_stage_working_days' => self::EARLY_STAGE_WORKING_DAYS,
            'pace_grace_working_days' => self::PACE_GRACE_WORKING_DAYS,
        ];
    }

    private function isBehindExpectedPace(int $completedHours, array $timeline): bool
    {
        if (($timeline['elapsed_working_days'] ?? 0) <= self::EARLY_STAGE_WORKING_DAYS) {
            return false;
        }

        return $completedHours < (float) ($timeline['minimum_expected_hours'] ?? 0);
    }

    private function inactiveWorkingDays(
        ?Carbon $startDate,
        ?Carbon $lastLogDate,
        Carbon $serverDate
    ): int {
        if (!$lastLogDate) {
            return 0;
        }

        $firstInactiveDate = $lastLogDate->copy()->addDay();
        if ($startDate && $firstInactiveDate->lt($startDate)) {
            $firstInactiveDate = $startDate->copy();
        }

        if ($firstInactiveDate->gt($serverDate)) {
            return 0;
        }

        return $this->countWorkingDays($firstInactiveDate, $serverDate);
    }

    private function countWorkingDays(Carbon $startDate, Carbon $endDate): int
    {
        if ($endDate->lt($startDate)) {
            return 0;
        }

        $workingDays = 0;
        for ($date = $startDate->copy(); $date->lte($endDate); $date->addDay()) {
            if (!$date->isWeekend()) {
                $workingDays++;
            }
        }

        return $workingDays;
    }

    private function parseDate(mixed $value): ?Carbon
    {
        if (!$value) {
            return null;
        }

        return Carbon::parse($value)->startOfDay();
    }

    private function summaryValue(array|object|null $summary, string $key, mixed $default = null): mixed
    {
        if (is_array($summary)) {
            return $summary[$key] ?? $default;
        }

        if (is_object($summary)) {
            return $summary->{$key} ?? $default;
        }

        return $default;
    }

    private function payload(
        string $status,
        string $message,
        string $severity,
        array $meta
    ): array {
        return [
            'status' => $status,
            'message' => $message,
            'severity' => $severity,
            'meta' => $meta,
        ];
    }
}
