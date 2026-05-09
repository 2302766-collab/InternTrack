<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TelescopeAccessTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        putenv('TELESCOPE_ENABLED=true');
        $_ENV['TELESCOPE_ENABLED'] = 'true';
        $_SERVER['TELESCOPE_ENABLED'] = 'true';

        parent::setUp();
    }

    protected function tearDown(): void
    {
        putenv('TELESCOPE_ENABLED=false');
        unset($_ENV['TELESCOPE_ENABLED'], $_SERVER['TELESCOPE_ENABLED']);

        parent::tearDown();
    }

    public function test_telescope_dashboard_is_accessible_when_enabled(): void
    {
        $response = $this->get('/telescope');

        $response->assertOk();
        $this->assertStringContainsString('Telescope', $response->getContent());
    }
}
