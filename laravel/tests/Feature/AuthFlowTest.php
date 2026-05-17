<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_student_can_register_successfully(): void
    {
        $studentRole = $this->ensureRoleExists('Student');

        $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/auth/register', [
                'name' => 'Juan Dela Cruz',
                'email' => 'juan@example.com',
                'gender' => 'Male',
                'password' => 'Password123',
                'password_confirmation' => 'Password123',
            ])
            ->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Registered successfully')
            ->assertJsonPath('data.user.name', 'Juan Dela Cruz')
            ->assertJsonPath('data.user.email', 'juan@example.com')
            ->assertJsonPath('data.user.gender', 'Male')
            ->assertJsonPath('data.user.role', 'Student');

        $user = User::query()->where('email', 'juan@example.com')->firstOrFail();

        $this->assertSame($studentRole->id, $user->role_id);
        $this->assertSame('Male', $user->gender);
        $this->assertTrue(Hash::check('Password123', $user->password));
        $this->assertCount(1, $user->tokens);
    }

    public function test_duplicate_email_registration_is_blocked(): void
    {
        $this->createUserWithRole('Student', [
            'email' => 'juan@example.com',
        ]);

        $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/auth/register', [
                'name' => 'Juan Dela Cruz',
                'email' => 'juan@example.com',
                'gender' => 'Male',
                'password' => 'Password123',
                'password_confirmation' => 'Password123',
            ])
            ->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Validation failed.')
            ->assertJsonPath('data.errors.email.0', 'The email has already been taken.');
    }

    public function test_users_can_login_and_receive_their_role(): void
    {
        foreach (['Student', 'Supervisor', 'Adviser', 'Admin'] as $roleName) {
            $user = $this->createUserWithRole($roleName, [
                'email' => strtolower($roleName) . '@example.com',
                'password' => Hash::make('Password123'),
            ]);

            $this->withHeader('Accept', 'application/json')
                ->post('/api/v1/auth/login', [
                    'email' => $user->email,
                    'password' => 'Password123',
                ])
                ->assertOk()
                ->assertJsonPath('success', true)
                ->assertJsonPath('message', 'Login successful')
                ->assertJsonPath('data.user.id', $user->id)
                ->assertJsonPath('data.user.email', $user->email)
                ->assertJsonPath('data.user.gender', $user->gender)
                ->assertJsonPath('data.user.role', $roleName);
        }
    }

    public function test_login_with_invalid_credentials_is_rejected(): void
    {
        $user = $this->createUserWithRole('Student', [
            'email' => 'juan@example.com',
            'password' => Hash::make('Password123'),
        ]);

        $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/auth/login', [
                'email' => $user->email,
                'password' => 'WrongPassword123',
            ])
            ->assertStatus(401)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Invalid credentials');
    }

    public function test_authenticated_user_can_retrieve_current_session_profile(): void
    {
        $user = $this->createUserWithRole('Supervisor');
        $token = $user->createToken('api-token')->plainTextToken;

        $this->withHeader('Accept', 'application/json')
            ->withToken($token)
            ->get('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Authenticated user')
            ->assertJsonPath('data.user.id', $user->id)
            ->assertJsonPath('data.user.email', $user->email)
            ->assertJsonPath('data.user.gender', $user->gender)
            ->assertJsonPath('data.user.role', 'Supervisor');
    }

    public function test_login_access_token_can_be_reused_for_authenticated_requests_until_logout(): void
    {
        $user = $this->createUserWithRole('Adviser', [
            'email' => 'adviser@example.com',
            'password' => Hash::make('Password123'),
        ]);

        $loginResponse = $this->withHeader('Accept', 'application/json')
            ->post('/api/v1/auth/login', [
                'email' => $user->email,
                'password' => 'Password123',
            ])
            ->assertOk()
            ->assertJsonPath('success', true);

        $token = $loginResponse->json('data.access_token');

        $this->assertIsString($token);
        $this->assertNotSame('', $token);

        $this->withHeader('Accept', 'application/json')
            ->withToken($token)
            ->get('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.user.id', $user->id)
            ->assertJsonPath('data.user.role', 'Adviser');

        $this->withHeader('Accept', 'application/json')
            ->withToken($token)
            ->post('/api/v1/auth/logout')
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->app['auth']->forgetGuards();

        $this->withHeader('Accept', 'application/json')
            ->withToken($token)
            ->get('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    public function test_current_session_profile_requires_authentication(): void
    {
        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    public function test_logout_revokes_the_current_access_token(): void
    {
        $user = $this->createUserWithRole('Student');
        $token = $user->createToken('api-token')->plainTextToken;

        $this->withHeader('Accept', 'application/json')
            ->withToken($token)
            ->post('/api/v1/auth/logout')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Logged out successfully');

        $this->assertCount(0, $user->fresh()->tokens);

        $this->app['auth']->forgetGuards();

        $this->withHeader('Accept', 'application/json')
            ->withToken($token)
            ->get('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    private function ensureRoleExists(string $roleName): Role
    {
        return Role::query()->firstOrCreate(['name' => $roleName]);
    }

    private function createUserWithRole(string $roleName, array $attributes = []): User
    {
        return User::factory()->create([
            'role_id' => $this->ensureRoleExists($roleName)->id,
            ...$attributes,
        ]);
    }
}
