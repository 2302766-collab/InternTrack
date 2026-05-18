<?php

namespace Tests\Feature;

use Laravel\Telescope\TelescopeApplicationServiceProvider;
use Tests\TestCase;

class TelescopeAccessTest extends TestCase
{
    public function test_telescope_dashboard_is_accessible_when_enabled(): void
    {
        if (! class_exists(TelescopeApplicationServiceProvider::class)) {
            $this->markTestSkipped('Laravel Telescope is not installed in this environment.');
        }

        putenv('TELESCOPE_ENABLED=true');
        $_ENV['TELESCOPE_ENABLED'] = 'true';
        $_SERVER['TELESCOPE_ENABLED'] = 'true';

        $this->refreshApplication();

        $response = $this->get('/telescope');

        $response->assertOk();
        $this->assertStringContainsString('Telescope', $response->getContent());

        putenv('TELESCOPE_ENABLED=false');
        unset($_ENV['TELESCOPE_ENABLED'], $_SERVER['TELESCOPE_ENABLED']);
    }
}
