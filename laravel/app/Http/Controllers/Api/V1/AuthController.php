<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\InputSanitizationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    private const MAX_AVATAR_BYTES = 5 * 1024 * 1024;

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

    private function userPayload(User $user): array
    {
        $roleName = $user->loadMissing('role')->role?->name;

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'gender' => $user->gender,
            'role' => $roleName,
            'avatar_base64' => $user->avatar_base64,
        ];
    }

    private function normalizeAvatarBase64(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim($value);
        if ($trimmed === '') {
            return null;
        }

        if (str_contains($trimmed, ',')) {
            $parts = explode(',', $trimmed, 2);
            if (count($parts) === 2 && str_contains($parts[0], ';base64')) {
                $trimmed = $parts[1];
            }
        }

        return preg_replace('/\s+/', '', $trimmed) ?: null;
    }

    private function validatedAvatarBase64(?string $value): ?string
    {
        $normalized = $this->normalizeAvatarBase64($value);
        if ($normalized === null) {
            return null;
        }

        $decoded = base64_decode($normalized, true);
        if ($decoded === false) {
            throw ValidationException::withMessages([
                'avatar_base64' => 'Profile photo must be a valid base64 image.',
            ]);
        }

        if (strlen($decoded) > self::MAX_AVATAR_BYTES) {
            throw ValidationException::withMessages([
                'avatar_base64' => 'Profile photo must be 5MB or smaller.',
            ]);
        }

        $finfo = new \finfo(FILEINFO_MIME_TYPE);
        $mimeType = $finfo->buffer($decoded) ?: '';

        if (! in_array($mimeType, ['image/jpeg', 'image/png'], true)) {
            throw ValidationException::withMessages([
                'avatar_base64' => 'Profile photo must be a JPG or PNG image.',
            ]);
        }

        return $normalized;
    }

    // POST /api/v1/auth/register
    public function register(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'gender' => ['required', 'string', 'in:Male,Female'],
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
            'gender' => $validated['gender'],
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
                'gender' => $user->gender,
                'role' => $roleName,
                'avatar_base64' => $user->avatar_base64,
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

        $user = User::query()
            ->with('role')
            ->where('email', $sanitizedEmail)
            ->first();

        if (!$user || !Hash::check($validated['password'], $user->password)) {
            Log::warning('Login failed due to invalid credentials.', [
                'email' => $sanitizedEmail,
            ]);

            return $this->fail('Invalid credentials', null, 401);
        }

        $roleName = $user->role?->name;
        if (!is_string($roleName) || trim($roleName) === '') {
            Log::error('Login blocked because the authenticated user has no resolvable role.', [
                'user_id' => $user->id,
                'email' => $user->email,
                'role_id' => $user->role_id,
            ]);

            return $this->fail('Account role is not configured. Contact support.', null, 500);
        }

        $token = $user->createToken('api-token')->plainTextToken;

        Log::info('Login successful.', [
            'user_id' => $user->id,
            'role' => $roleName,
        ]);

        return $this->success('Login successful', [
            'access_token' => $token,
            'user' => $this->userPayload($user),
        ]);
    }

    // POST /api/v1/auth/logout (auth:sanctum)
    public function logout(Request $request)
    {
        $request->user()?->currentAccessToken()?->delete();

        return $this->success('Logged out successfully');
    }

    // GET /api/v1/auth/me (auth:sanctum)
    public function me(Request $request)
    {
        $user = $request->user()?->loadMissing('role');
        if (!$user) {
            return $this->fail('Unauthenticated.', null, 401);
        }

        $roleName = $user->role?->name;
        if (!is_string($roleName) || trim($roleName) === '') {
            Log::error('Authenticated session could not resolve a user role.', [
                'user_id' => $user->id,
                'email' => $user->email,
                'role_id' => $user->role_id,
            ]);

            return $this->fail('Account role is not configured. Contact support.', null, 500);
        }

        Log::info('Authenticated user profile resolved.', [
            'user_id' => $user->id,
            'role' => $roleName,
        ]);

        return $this->success('Authenticated user', [
            'user' => $this->userPayload($user),
        ]);
    }

    // PATCH /api/v1/auth/profile (auth:sanctum)
    public function updateProfile(Request $request)
    {
        $user = $request->user()?->loadMissing('role');
        if (!$user) {
            return $this->fail('Unauthenticated.', null, 401);
        }

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'gender' => ['required', 'string', 'in:Male,Female'],
        ]);

        $originalName = $validated['name'];
        $sanitizedName = $this->sanitizer->sanitizeString($validated['name']);

        $this->sanitizer->logSanitization('name', $originalName, $sanitizedName);

        $user->update([
            'name' => $sanitizedName,
            'gender' => $validated['gender'],
        ]);

        return $this->success('Profile updated successfully.', [
            'user' => $this->userPayload($user->fresh()->loadMissing('role')),
        ]);
    }

    // PATCH /api/v1/auth/avatar (auth:sanctum)
    public function updateAvatar(Request $request)
    {
        $user = $request->user()?->loadMissing('role');
        if (! $user) {
            return $this->fail('Unauthenticated.', null, 401);
        }

        $validated = $request->validate([
            'avatar_base64' => ['nullable', 'string'],
        ]);

        $user->update([
            'avatar_base64' => $this->validatedAvatarBase64(
                $validated['avatar_base64'] ?? null
            ),
        ]);

        return $this->success('Profile photo updated successfully.', [
            'user' => $this->userPayload($user->fresh()->loadMissing('role')),
        ]);
    }
}
