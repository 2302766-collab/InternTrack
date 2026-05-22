<?php

namespace Tests\Feature;

use Laravel\Telescope\TelescopeServiceProvider;
use Laravel\Telescope\TelescopeApplicationServiceProvider;
use Tests\TestCase;

class TelescopeAccessTest extends TestCase
{
    public function test_telescope_dashboard_is_accessible_when_enabled(): void
    {
        if (! class_exists(TelescopeApplicationServiceProvider::class)) {
            $this->markTestSkipped('Laravel Telescope is not installed in this environment.');
        }

        // PHPUnit forces TELESCOPE_ENABLED=false via phpunit.xml, so toggle
        // Telescope through runtime config and re-register its provider.
        config()->set('telescope.enabled', true);
        $this->app->register(TelescopeServiceProvider::class, true);

        $response = $this->get('/telescope');

        $response->assertOk();
        $this->assertStringContainsString('Telescope', $response->getContent());
    }
}
