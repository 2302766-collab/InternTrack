<?php

namespace App\Observers;

use App\Models\LogEntry;
use App\Services\DashboardCacheService;

class LogEntryObserver
{
    public function __construct(private readonly DashboardCacheService $dashboardCache)
    {
    }

    public function saved(LogEntry $logEntry): void
    {
        $this->forgetAffectedDashboards($logEntry);
    }

    public function deleted(LogEntry $logEntry): void
    {
        $this->forgetAffectedDashboards($logEntry);
    }

    private function forgetAffectedDashboards(LogEntry $logEntry): void
    {
        $profileIds = [
            $logEntry->internship_profile_id,
            $logEntry->wasChanged('internship_profile_id')
                ? $this->normalizeNullableInt($logEntry->getOriginal('internship_profile_id'))
                : null,
        ];

        foreach (array_unique(array_filter($profileIds, static fn (?int $id): bool => $id !== null)) as $profileId) {
            $this->dashboardCache->forgetForInternshipProfileId($profileId);
        }

        $this->dashboardCache->forgetAdminDashboard();
    }

    private function normalizeNullableInt(mixed $value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        return (int) $value;
    }
}
