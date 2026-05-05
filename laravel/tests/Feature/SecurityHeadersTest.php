<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SecurityHeadersTest extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function api_responses_include_security_headers()
    {
        $response = $this->getJson('/api/v1/health');

        // Check for security headers
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-Frame-Options', 'DENY');
        $response->assertHeader('X-XSS-Protection', '1; mode=block');
        $response->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->assertHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
        $response->assertHeader('Content-Security-Policy');
    }

    /** @test */
    public function auth_endpoints_include_security_headers()
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'test@example.com',
            'password' => 'password',
        ]);

        // Should still include security headers even on auth errors
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-Frame-Options', 'DENY');
        $response->assertHeader('X-XSS-Protection', '1; mode=block');
    }

    /** @test */
    public function register_endpoint_includes_security_headers()
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'password',
            'password_confirmation' => 'password',
        ]);

        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-Frame-Options', 'DENY');
        $response->assertHeader('X-XSS-Protection', '1; mode=block');
        $response->assertHeader('Content-Security-Policy');
    }

    /** @test */
    public function csp_header_is_restrictive_for_api()
    {
        $response = $this->getJson('/api/v1/health');
        
        $csp = $response->headers->get('Content-Security-Policy');
        
        // Check CSP contains restrictive directives
        $this->assertStringContainsString("default-src 'self'", $csp);
        $this->assertStringContainsString("script-src 'self'", $csp);
        $this->assertStringContainsString("frame-ancestors 'none'", $csp);
        $this->assertStringContainsString("form-action 'self'", $csp);
    }

    /** @test */
    public function hsts_header_only_in_production_with_https()
    {
        // Test local environment (should not have HSTS)
        $response = $this->getJson('/api/v1/health');
        $response->assertHeaderMissing('Strict-Transport-Security');
    }

    /** @test */
    public function error_responses_include_security_headers()
    {
        $response = $this->getJson('/api/v1/nonexistent-endpoint');

        // 404 responses should still have security headers
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-Frame-Options', 'DENY');
        $response->assertHeader('X-XSS-Protection', '1; mode=block');
    }
}
