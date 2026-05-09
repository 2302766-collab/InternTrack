<?php

namespace App\Providers;

use App\Models\User;
use Illuminate\Support\Facades\Gate;
use Laravel\Telescope\IncomingEntry;
use Laravel\Telescope\Telescope;
use Laravel\Telescope\TelescopeApplicationServiceProvider;

class TelescopeServiceProvider extends TelescopeApplicationServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Telescope::night();

        $this->hideSensitiveRequestDetails();

        $isMonitoredEnvironment = $this->app->environment(['local', 'testing']);

        Telescope::filter(function (IncomingEntry $entry) use ($isMonitoredEnvironment) {
            $request = request();
            $isApiRequest = $request->is('api/*');

            return $isMonitoredEnvironment ||
                   $isApiRequest ||
                   $entry->isReportableException() ||
                   $entry->isFailedRequest() ||
                   $entry->isFailedJob() ||
                   $entry->isScheduledTask() ||
                   $entry->hasMonitoredTag();
        });

        Telescope::tag(function (IncomingEntry $entry): array {
            $request = request();
            $requestId = (string) $request->attributes->get(\App\Http\Middleware\RequestTracingMiddleware::REQUEST_ID_ATTRIBUTE);
            $userId = $request->user()?->getAuthIdentifier();

            return array_values(array_filter([
                $request->is('api/*') ? 'api' : null,
                filled($requestId) ? 'request:'.$requestId : null,
                $userId !== null ? 'user:'.$userId : null,
                $entry->isFailedRequest() ? 'failed-request' : null,
            ]));
        });
    }

    /**
     * Prevent sensitive request details from being logged by Telescope.
     */
    protected function hideSensitiveRequestDetails(): void
    {
        if ($this->app->environment('local')) {
            return;
        }

        Telescope::hideRequestParameters(['_token']);

        Telescope::hideRequestHeaders([
            'cookie',
            'x-csrf-token',
            'x-xsrf-token',
        ]);
    }

    /**
     * Register the Telescope gate.
     *
     * This gate determines who can access Telescope in non-local environments.
     */
    protected function gate(): void
    {
        Gate::define('viewTelescope', function (?User $user = null) {
            if ($this->app->environment(['local', 'testing'])) {
                return true;
            }

            if ((bool) env('TELESCOPE_OPEN_ACCESS', false)) {
                return true;
            }

            return strcasecmp((string) $user?->role?->name, 'Admin') === 0;
        });
    }
}
