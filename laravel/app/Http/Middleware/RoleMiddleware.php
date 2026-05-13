<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class RoleMiddleware
{
    public function handle(Request $request, Closure $next, string $role, ?string $message = null)
    {
        $user = $request->user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated.',
                'data' => null,
            ], 401);
        }

        $roleName = $user->loadMissing('role')->role?->name;
        if (!is_string($roleName) || trim($roleName) === '') {
            Log::error('Role middleware blocked a request because the user role could not be resolved.', [
                'user_id' => $user->getAuthIdentifier(),
                'expected_role' => $role,
                'path' => $request->path(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Account role is not configured. Contact support.',
                'data' => null,
            ], 500);
        }

        if (strcasecmp($roleName, $role) !== 0) {
            Log::warning('Role authorization failed.', [
                'user_id' => $user->getAuthIdentifier(),
                'expected_role' => $role,
                'actual_role' => $roleName,
                'path' => $request->path(),
            ]);

            return response()->json([
                'success' => false,
                'message' => $message ?? 'Forbidden: insufficient role.',
                'data' => null,
            ], 403);
        }

        return $next($request);
    }
}
