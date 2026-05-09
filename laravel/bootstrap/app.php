<?php

use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'role' => \App\Http\Middleware\RoleMiddleware::class,
            'security.headers' => \App\Http\Middleware\SecurityHeadersMiddleware::class,
        ]);
        
        // Apply security headers to all API routes
        $middleware->group('api', [
            \App\Http\Middleware\RequestTracingMiddleware::class,
            \App\Http\Middleware\SecurityHeadersMiddleware::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $isApiRequest = static fn (Request $request): bool => $request->is('api/*') || $request->expectsJson();
        $secureApiResponse = static function (Request $request, array $payload, int $status): JsonResponse {
            $response = response()->json($payload, $status);

            return \App\Http\Middleware\SecurityHeadersMiddleware::applyHeaders($response, $request);
        };

        $exceptions->render(function (ValidationException $exception, Request $request) use ($isApiRequest, $secureApiResponse) {
            if (! $isApiRequest($request)) {
                return null;
            }

            return $secureApiResponse($request, [
                'success' => false,
                'message' => 'Validation failed.',
                'data' => [
                    'errors' => $exception->errors(),
                ],
            ], 422);
        });

        $exceptions->render(function (AuthenticationException $exception, Request $request) use ($isApiRequest, $secureApiResponse) {
            if (! $isApiRequest($request)) {
                return null;
            }

            return $secureApiResponse($request, [
                'success' => false,
                'message' => 'Unauthenticated.',
                'data' => null,
            ], 401);
        });

        $exceptions->render(function (NotFoundHttpException $exception, Request $request) use ($isApiRequest, $secureApiResponse) {
            if (! $isApiRequest($request)) {
                return null;
            }

            return $secureApiResponse($request, [
                'success' => false,
                'message' => 'Resource not found.',
                'data' => null,
            ], 404);
        });

        $exceptions->render(function (\Throwable $exception, Request $request) use ($isApiRequest, $secureApiResponse) {
            if (! $isApiRequest($request)) {
                return null;
            }

            if (
                $exception instanceof ValidationException ||
                $exception instanceof AuthenticationException ||
                $exception instanceof NotFoundHttpException
            ) {
                return null;
            }

            $status = $exception instanceof HttpExceptionInterface ? $exception->getStatusCode() : 500;
            $status = ($status >= 400 && $status < 600) ? $status : 500;

            return $secureApiResponse($request, [
                'success' => false,
                'message' => $status >= 500
                    ? 'An unexpected server error occurred.'
                    : 'Request could not be processed.',
                'data' => null,
            ], $status);
        });
    })->create();
