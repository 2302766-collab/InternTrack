<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Log;
use Mockery;
use Tests\TestCase;

class ApiRequestTracingTest extends TestCase
{
    public function test_api_requests_reuse_request_id_header_and_log_duration(): void
    {
        Log::spy();

        $response = $this->withHeaders([
            'X-Request-ID' => 'trace-request-123',
        ])->getJson('/api/v1/health');

        $response
            ->assertOk()
            ->assertHeader('X-Request-ID', 'trace-request-123');

        Log::shouldHaveReceived('shareContext')
            ->once()
            ->with(Mockery::on(function (array $context): bool {
                return $context['request_id'] === 'trace-request-123'
                    && $context['method'] === 'GET'
                    && $context['path'] === 'api/v1/health';
            }));

        Log::shouldHaveReceived('info')
            ->once()
            ->with('API request handled', Mockery::on(function (array $context): bool {
                return $context['request_id'] === 'trace-request-123'
                    && $context['status'] === 200
                    && $context['method'] === 'GET'
                    && $context['path'] === 'api/v1/health'
                    && isset($context['duration_ms'])
                    && is_numeric($context['duration_ms']);
            }));
    }

    public function test_api_requests_generate_request_ids_when_missing(): void
    {
        $response = $this->getJson('/api/v1/health');

        $response->assertOk();

        $requestId = (string) $response->headers->get('X-Request-ID');

        $this->assertNotSame('', $requestId);
        $this->assertMatchesRegularExpression(
            '/^[A-Za-z0-9\-_.:]+$/',
            $requestId
        );
    }
}
