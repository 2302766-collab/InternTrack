<?php

namespace App\Observers;

use App\Models\User;
use App\Services\DashboardCacheService;

class UserObserver
{
    public function __construct(private readonly DashboardCacheService $dashboardCache)
    {
    }

    public function saved(User $user): void
    {
        $this->dashboardCache->forgetAdminDashboard();
        $this->dashboardCache->forgetManagedUsers();
    }

    public function deleted(User $user): void
    {
        $this->dashboardCache->forgetAdminDashboard();
        $this->dashboardCache->forgetManagedUsers();
    }
}
