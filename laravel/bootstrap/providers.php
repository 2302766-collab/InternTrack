<?php

use Laravel\Telescope\TelescopeApplicationServiceProvider;

$providers = [
    App\Providers\AppServiceProvider::class,
];

// Telescope is a dev-only package in this project, so production/no-dev installs
// must not hard-fail while bootstrapping the app.
if (class_exists(TelescopeApplicationServiceProvider::class)) {
    $providers[] = App\Providers\TelescopeServiceProvider::class;
}

return $providers;
