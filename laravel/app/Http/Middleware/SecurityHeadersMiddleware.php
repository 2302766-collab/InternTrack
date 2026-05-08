<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SecurityHeadersMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure  $next
     * @return mixed
     */
    public function handle(Request $request, Closure $next)
    {
        $response = $next($request);

        return self::applyHeaders($response, $request);
    }

    public static function applyHeaders(Response $response, Request $request): Response
    {
        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('X-XSS-Protection', '1; mode=block');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->headers->set('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
        
        // Content Security Policy (CSP) - restrictive for API
        $csp = "default-src 'self'; "
              . "script-src 'self'; "
              . "style-src 'self'; "
              . "img-src 'self' data:; "
              . "font-src 'self'; "
              . "connect-src 'self'; "
              . "frame-ancestors 'none'; "
              . "base-uri 'self'; "
              . "form-action 'self'";
        
        $response->headers->set('Content-Security-Policy', $csp);

        // Add HSTS for HTTPS (only in production)
        if (config('app.env') === 'production' && $request->secure()) {
            $response->headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
        }

        return $response;
    }
}
