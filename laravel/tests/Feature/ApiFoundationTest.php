<?php

namespace Tests\Feature;

use Tests\TestCase;

class ApiFoundationTest extends TestCase
{
    public function test_health_endpoint_returns_expected_payload(): void
    {
        $response = $this->getJson('/api/v1/health');

        $response
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'API is running')
            ->assertJsonStructure([
                'success',
                'message',
                'timestamp',
            ]);
    }

    public function test_missing_api_route_returns_standardized_json_404(): void
    {
        $response = $this->get('/api/v1/does-not-exist');

        $response
            ->assertNotFound()
            ->assertJson([
                'success' => false,
                'message' => 'Resource not found.',
                'data' => null,
            ]);
    }
}
