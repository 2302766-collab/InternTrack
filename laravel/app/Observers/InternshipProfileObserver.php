<?php

namespace App\Observers;

use App\Models\InternshipProfile;
use App\Services\DashboardCacheService;

class InternshipProfileObserver
{
    public function __construct(private readonly DashboardCacheService $dashboardCache)
    {
    }

    public function saved(InternshipProfile $profile): void
    {
        $this->forgetAffectedDashboards($profile);
    }

    public function deleted(InternshipProfile $profile): void
    {
        $this->forgetAffectedDashboards($profile);
    }

    private function forgetAffectedDashboards(InternshipProfile $profile): void
    {
        $supervisorIds = [
            $profile->supervisor_id,
            $profile->wasChanged('supervisor_id')
                ? $this->normalizeNullableInt($profile->getOriginal('supervisor_id'))
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
