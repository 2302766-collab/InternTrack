<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Services\InputSanitizationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class InputSanitizationTest extends TestCase
{
    use RefreshDatabase;

    private InputSanitizationService $sanitizer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->sanitizer = app(InputSanitizationService::class);

        // Create roles for testing
        Role::create(['name' => 'Student']);
    }

    #[Test]
    public function register_sanitizes_name_and_email_inputs()
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => '  <script>alert("xss")</script>  Test User  ',
            'email' => '  TEST@EXAMPLE.COM  ',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(201);

        // Verify the user was created with sanitized data
        $user = User::where('email', 'test@example.com')->first();
        $this->assertNotNull($user);
        $this->assertEquals('Test User', $user->name); // HTML tags removed, whitespace trimmed
        $this->assertEquals('test@example.com', $user->email); // Lowercase, trimmed
    }

    #[Test]
    public function login_sanitizes_email_input()
    {
        // Create a user first
        $user = User::create([
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => bcrypt('password123'),
            'role_id' => Role::where('name', 'Student')->first()->id,
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => '  TEST@EXAMPLE.COM  ',
            'password' => 'password123',
        ]);

        $response->assertStatus(200);
        $response->assertJsonPath('success', true);
    }

    #[Test]
    public function sanitization_service_removes_html_tags()
    {
        $input = '<script>alert("xss")</script>Hello World';
        $sanitized = $this->sanitizer->sanitizeString($input);

        $this->assertEquals('Hello World', $sanitized);
        $this->assertStringNotContainsString('<script>', $sanitized);
    }

    #[Test]
    public function sanitization_service_normalizes_whitespace()
    {
        $input = "  Hello    \n   World  ";
        $sanitized = $this->sanitizer->sanitizeString($input);

        $this->assertEquals('Hello World', $sanitized);
    }

    #[Test]
    public function sanitization_service_sanitizes_email()
    {
        $input = '  <b>TEST@EXAMPLE.COM</b>  ';
        $sanitized = $this->sanitizer->sanitizeEmail($input);

        $this->assertEquals('test@example.com', $sanitized);
    }

    #[Test]
    public function sanitization_service_sanitizes_arrays()
    {
        $input = [
            'name' => '<script>alert("xss")</script>Test',
            'description' => '  Hello    World  ',
            'number' => 123, // Non-string values should pass through
        ];

        $sanitized = $this->sanitizer->sanitizeArray($input);

        $this->assertEquals('Test', $sanitized['name']);
        $this->assertEquals('Hello World', $sanitized['description']);
        $this->assertEquals(123, $sanitized['number']);
    }

    #[Test]
    public function sanitization_logs_changes()
    {
        // Enable log capture
        Log::shouldReceive('info')->once()->with('Input sanitized', \Mockery::on(function ($data) {
            return $data['field'] === 'name' &&
                   $data['original_length'] > 0 &&
                   $data['sanitized_length'] > 0 &&
                   $data['changed'] === true &&
                   isset($data['timestamp']);
        }));

        $input = '<script>alert("xss")</script>Hello';
        $sanitized = $this->sanitizer->sanitizeString($input);

        $this->sanitizer->logSanitization('name', $input, $sanitized);
    }

    #[Test]
    public function sanitization_does_not_log_unchanged_inputs()
    {
        Log::spy();

        $input = 'Hello World';
        $sanitized = $this->sanitizer->sanitizeString($input);

        $this->sanitizer->logSanitization('name', $input, $sanitized);

        Log::shouldNotHaveReceived('info');
    }

    #[Test]
    public function valid_data_passes_through_unchanged()
    {
        $validName = 'John Doe';
        $validEmail = 'john.doe@example.com';

        $sanitizedName = $this->sanitizer->sanitizeString($validName);
        $sanitizedEmail = $this->sanitizer->sanitizeEmail($validEmail);

        // Valid data should remain unchanged
        $this->assertEquals($validName, $sanitizedName);
        $this->assertEquals($validEmail, $sanitizedEmail);
    }

    #[Test]
    public function text_sanitization_preserves_line_breaks()
    {
        $input = "Hello\nWorld\r\nTest";
        $sanitized = $this->sanitizer->sanitizeText($input);

        $this->assertEquals("Hello\nWorld\nTest", $sanitized);
    }
}
