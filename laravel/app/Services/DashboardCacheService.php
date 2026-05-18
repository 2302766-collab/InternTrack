<?php

namespace App\Services;

use App\Models\InternshipProfile;
use Closure;
use Illuminate\Support\Facades\Cache;

class DashboardCacheService
{
    public const TTL_SECONDS = 300;
    private const ADMIN_DASHBOARD_VERSION_KEY = 'dashboard:admin:version';

    public function rememberSupervisorDashboard(int $supervisorId, Closure $callback): array
    {
        return Cache::remember(
            $this->supervisorDashboardKey($supervisorId),
            self::TTL_SECONDS,
            $callback,
        );
    }

    public function rememberAdminDashboard(string $periodKey, Closure $callback): array
    {
        return Cache::remember(
            $this->adminDashboardKey($periodKey),
            self::TTL_SECONDS,
            $callback,
        );
    }

    public function rememberManagedUsers(Closure $callback): array
    {
        return Cache::remember(
            $this->managedUsersKey(),
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

    public function adminDashboardKey(?string $periodKey = null): string
    {
        return sprintf(
            'dashboard:admin:v%s:%s',
            $this->adminDashboardVersion(),
            $periodKey ?? 'latest',
        );
    }

    public function managedUsersKey(): string
    {
        return 'dashboard:admin:managed-users';
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
        Cache::increment(self::ADMIN_DASHBOARD_VERSION_KEY);
    }

    public function forgetManagedUsers(): void
    {
        Cache::forget($this->managedUsersKey());
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

    private function adminDashboardVersion(): int
    {
        $version = Cache::get(self::ADMIN_DASHBOARD_VERSION_KEY);

        if (! is_numeric($version)) {
            Cache::forever(self::ADMIN_DASHBOARD_VERSION_KEY, 1);

            return 1;
        }

        return (int) $version;
    }
}
