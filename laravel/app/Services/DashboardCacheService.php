<?php

namespace App\Services;

use App\Models\InternshipProfile;
use Closure;
use Illuminate\Support\Facades\Cache;

class DashboardCacheService
{
    public const TTL_SECONDS = 300;

    public function rememberSupervisorDashboard(int $supervisorId, Closure $callback): array
    {
        return Cache::remember(
            $this->supervisorDashboardKey($supervisorId),
            self::TTL_SECONDS,
            $callback,
        );
    }

    public function rememberAdminDashboard(Closure $callback): array
    {
        return Cache::remember(
            $this->adminDashboardKey(),
            self::TTL_SECONDS,
            $callback,
        );
    }

    public function supervisorDashboardKey(int $supervisorId, ?string $date = null): string
    {
        return sprintf(
            'dashboard:supervisor:%d:%s',
            $supervisorId,
            $date ?? now()->toDateString(),
        );
    }

    public function adminDashboardKey(): string
    {
        return 'dashboard:admin';
    }

    public function forgetSupervisorDashboard(?int $supervisorId): void
    {
        if ($supervisorId === null) {
            return;
        }

        Cache::forget($this->supervisorDashboardKey($supervisorId));
    }

    public function forgetAdminDashboard(): void
    {
        Cache::forget($this->adminDashboardKey());
    }

    public function forgetForInternshipProfileId(?int $profileId): void
    {
        if ($profileId === null) {
            $this->forgetAdminDashboard();

            return;
        }

        $supervisorId = InternshipProfile::query()
            ->whereKey($profileId)
            ->value('supervisor_id');

        if ($supervisorId !== null) {
            $this->forgetSupervisorDashboard((int) $supervisorId);
        }

        $this->forgetAdminDashboard();
    }
}
