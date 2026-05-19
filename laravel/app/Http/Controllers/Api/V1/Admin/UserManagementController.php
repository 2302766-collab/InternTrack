<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\User;
use App\Services\DashboardCacheService;
use App\Services\InputSanitizationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class UserManagementController extends Controller
{
    private const MANAGEABLE_ROLES = ['Student', 'Adviser', 'Supervisor'];

    public function __construct(
        private InputSanitizationService $sanitizer,
        private readonly DashboardCacheService $dashboardCache
    )
    {
    }

    public function index()
    {
        $users = $this->dashboardCache->rememberManagedUsers(function (): array {
            return User::query()
                ->join('roles', 'roles.id', '=', 'users.role_id')
                ->whereIn('roles.name', self::MANAGEABLE_ROLES)
                ->select([
                    'users.id',
                    'users.name',
                    'users.email',
                    'users.gender',
                    'users.avatar_base64',
                    'roles.name as role',
                ])
                ->orderByRaw(
                    "CASE roles.name
                        WHEN 'Student' THEN 1
                        WHEN 'Adviser' THEN 2
                        WHEN 'Supervisor' THEN 3
                        ELSE 4
                    END"
                )
                ->orderBy('users.name')
                ->get()
                ->map(fn ($user) => [
                    'id' => (int) $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'gender' => $user->gender,
                    'avatar_base64' => $user->avatar_base64,
                    'role' => $user->role,
                ])
                ->all();
        });

        return response()->json([
            'success' => true,
            'message' => 'Managed users retrieved successfully.',
            'data' => $users,
        ], 200);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'gender' => ['required', 'string', 'in:Male,Female'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'role' => ['required', 'string', Rule::in(self::MANAGEABLE_ROLES)],
        ]);

        $sanitizedName = $this->sanitizer->sanitizeString($validated['name']);
        $sanitizedEmail = $this->sanitizer->sanitizeEmail($validated['email']);

        $this->sanitizer->logSanitization('name', $validated['name'], $sanitizedName);
        $this->sanitizer->logSanitization('email', $validated['email'], $sanitizedEmail);

        $role = Role::query()->where('name', $validated['role'])->first();

        if (! $role) {
            return response()->json([
                'success' => false,
                'message' => 'Selected role is not configured.',
                'data' => null,
            ], 422);
        }

        $user = User::create([
            'name' => $sanitizedName,
            'email' => $sanitizedEmail,
            'gender' => $validated['gender'],
            'password' => Hash::make($validated['password']),
            'role_id' => $role->id,
        ])->load('role');

        return response()->json([
            'success' => true,
            'message' => "{$role->name} account created successfully.",
            'data' => $this->userPayload($user),
        ], 201);
    }

    public function destroy(int $userId)
    {
        $user = User::query()->with('role')->find($userId);

        if (! $user) {
            return response()->json([
                'success' => false,
                'message' => 'User not found.',
                'data' => null,
            ], 404);
        }

        $roleName = $user->role?->name;
        if (! in_array($roleName, self::MANAGEABLE_ROLES, true)) {
            return response()->json([
                'success' => false,
                'message' => 'Only student, adviser, and supervisor accounts can be removed here.',
                'data' => null,
            ], 422);
        }

        $payload = $this->userPayload($user);
        $user->delete();

        return response()->json([
            'success' => true,
            'message' => "{$roleName} account removed successfully.",
            'data' => $payload,
        ], 200);
    }

    private function userPayload(User $user): array
    {
        $roleName = $user->role?->name ?? '';

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'gender' => $user->gender,
            'avatar_base64' => $user->avatar_base64,
            'role' => $roleName,
        ];
    }
}
