<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\InputSanitizationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    private InputSanitizationService $sanitizer;

    public function __construct(InputSanitizationService $sanitizer)
    {
        $this->sanitizer = $sanitizer;
    }

    private function success(string $message, $data = null, int $status = 200)
    {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $data,
        ], $status);
    }

    private function fail(string $message, $data = null, int $status = 422)
    {
        return response()->json([
            'success' => false,
            'message' => $message,
            'data' => $data,
        ], $status);
    }

    // POST /api/v1/auth/register
    public function register(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'], // needs password_confirmation
        ]);

        // Sanitize inputs
        $originalName = $validated['name'];
        $originalEmail = $validated['email'];
        
        $sanitizedName = $this->sanitizer->sanitizeString($validated['name']);
        $sanitizedEmail = $this->sanitizer->sanitizeEmail($validated['email']);

        // Log sanitization if changes occurred
        $this->sanitizer->logSanitization('name', $originalName, $sanitizedName);
        $this->sanitizer->logSanitization('email', $originalEmail, $sanitizedEmail);

        // Only Student self-register
        $studentRoleId = DB::table('roles')->where('name', 'Student')->value('id');

        if (!$studentRoleId) {
            return $this->fail('Student role not found. Run seeders.', null, 500);
        }

        $user = User::create([
            'name' => $sanitizedName,
            'email' => $sanitizedEmail,
            'password' => Hash::make($validated['password']),
            'role_id' => $studentRoleId,
        ]);

        $roleName = 'Student';
        $token = $user->createToken('api-token')->plainTextToken;

        return $this->success('Registered successfully', [
            'access_token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $roleName,
            ],
        ], 201);
    }

    // POST /api/v1/auth/login
    public function login(Request $request)
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        // Sanitize email input
        $originalEmail = $validated['email'];
        $sanitizedEmail = $this->sanitizer->sanitizeEmail($validated['email']);
        
        // Log sanitization if changes occurred
        $this->sanitizer->logSanitization('email', $originalEmail, $sanitizedEmail);

        $user = User::where('email', $sanitizedEmail)->first();

        if (!$user || !Hash::check($validated['password'], $user->password)) {
            return $this->fail('Invalid credentials', null, 401);
        }

        $roleName = DB::table('roles')->where('id', $user->role_id)->value('name');

        $token = $user->createToken('api-token')->plainTextToken;

        return $this->success('Login successful', [
            'access_token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $roleName,
            ],
        ]);
    }

    // POST /api/v1/auth/logout (auth:sanctum)
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return $this->success('Logged out successfully');
    }

    // GET /api/v1/auth/me (auth:sanctum)
    public function me(Request $request)
    {
        $user = $request->user();
        $roleName = DB::table('roles')->where('id', $user->role_id)->value('name');

        return $this->success('Authenticated user', [
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $roleName,
            ],
        ]);
    }
}
