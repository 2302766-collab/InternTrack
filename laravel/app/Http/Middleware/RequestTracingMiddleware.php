<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class RequestTracingMiddleware
{
    public const REQUEST_ID_ATTRIBUTE = 'request_id';

    private const REQUEST_ID_HEADER = 'X-Request-ID';

    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $requestId = $this->resolveRequestId($request);
        $startedAt = hrtime(true);
        $sharedContext = [
            'request_id' => $requestId,
            'method' => $request->getMethod(),
            'path' => ltrim($request->path(), '/'),
        ];

        $request->attributes->set(self::REQUEST_ID_ATTRIBUTE, $requestId);
        $request->headers->set(self::REQUEST_ID_HEADER, $requestId);
        Log::shareContext($sharedContext);

        try {
            $response = $next($request);
        } catch (Throwable $exception) {
            Log::warning('API request failed', array_merge(
                $sharedContext,
                $this->buildResponseContext($request, $startedAt, null, $exception)
            ));

            throw $exception;
        } finally {
            Log::withoutContext(array_keys($sharedContext));
        }

        $response->headers->set(self::REQUEST_ID_HEADER, $requestId);

        Log::info('API request handled', array_merge(
            $sharedContext,
            $this->buildResponseContext($request, $startedAt, $response)
        ));

        return $response;
    }

    private function resolveRequestId(Request $request): string
    {
        $incomingRequestId = preg_replace(
            '/[^A-Za-z0-9\-_.:]/',
            '',
            trim((string) $request->headers->get(self::REQUEST_ID_HEADER, ''))
        );

        return filled($incomingRequestId)
            ? Str::of($incomingRequestId)->limit(100, '')->value()
            : (string) Str::uuid();
    }

    private function buildResponseContext(
        Request $request,
        int $startedAt,
        ?Response $response = null,
        ?Throwable $exception = null
    ): array {
        $route = $request->route();
        $durationMs = round((hrtime(true) - $startedAt) / 1_000_000, 2);

        return array_filter([
            'route' => $route?->getName() ?? $route?->uri(),
            'status' => $response?->getStatusCode() ?? 500,
            'duration_ms' => $durationMs,
            'user_id' => $request->user()?->getAuthIdentifier(),
            'ip' => $request->ip(),
            'exception' => $exception ? $exception::class : null,
        ], static fn (mixed $value): bool => $value !== null);
    }
}
