<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

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

        $roleName = \DB::table('roles')->where('id', $user->role_id)->value('name');

        if (!$roleName || strcasecmp($roleName, $role) !== 0) {
            return response()->json([
                'success' => false,
                'message' => $message ?? 'Forbidden: insufficient role.',
                'data' => null,
            ], 403);
        }

        return $next($request);
    }
}
