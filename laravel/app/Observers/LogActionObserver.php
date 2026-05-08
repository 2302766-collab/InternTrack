<?php

namespace App\Observers;

use App\Models\LogAction;
use App\Services\DashboardCacheService;

class LogActionObserver
{
    public function __construct(private readonly DashboardCacheService $dashboardCache)
    {
    }

    public function saved(LogAction $logAction): void
    {
        $this->forgetAffectedDashboards($logAction);
    }

    public function deleted(LogAction $logAction): void
    {
        $this->forgetAffectedDashboards($logAction);
    }

    private function forgetAffectedDashboards(LogAction $logAction): void
    {
        $supervisorIds = [
            $logAction->supervisor_id,
            $logAction->wasChanged('supervisor_id')
                ? $this->normalizeNullableInt($logAction->getOriginal('supervisor_id'))
                : null,
        ];

        foreach (array_unique(array_filter($supervisorIds, static fn (?int $id): bool => $id !== null)) as $supervisorId) {
            $this->dashboardCache->forgetSupervisorDashboard($supervisorId);
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
