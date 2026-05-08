<?php

namespace App\Providers;

use App\Models\InternshipProfile;
use App\Models\LogAction;
use App\Models\LogEntry;
use App\Models\User;
use App\Observers\InternshipProfileObserver;
use App\Observers\LogActionObserver;
use App\Observers\LogEntryObserver;
use App\Observers\UserObserver;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        InternshipProfile::observe($this->app->make(InternshipProfileObserver::class));
        LogEntry::observe($this->app->make(LogEntryObserver::class));
        LogAction::observe($this->app->make(LogActionObserver::class));
        User::observe($this->app->make(UserObserver::class));
    }
}
