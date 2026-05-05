# InternTrack Backend (Laravel)

Sprint 1 foundation setup for the InternTrack backend API.

## Development Environment

- PHP: 8.2+
- Laravel: 12.x
- Database: MySQL 8.0+ (or MariaDB 10.6+)

## Installed Packages

### Runtime

- `laravel/framework`
- `laravel/sanctum`
- `laravel/tinker`

### Development

- `fakerphp/faker`
- `laravel/pail`
- `laravel/pint`
- `laravel/sail`
- `mockery/mockery`
- `nunomaduro/collision`
- `phpunit/phpunit`

## API Foundation Structure

- Versioned API prefix: `/api/v1`
- Health check endpoint: `GET /api/v1/health`
- Organized API route files:
  - `routes/api.php`
  - `routes/api/v1/health.php`
  - `routes/api/v1/auth.php` (placeholder group for future auth routes)

## Standard API Response Baseline

- Health response:
  - `success`
  - `message`
  - `timestamp`
- Standard JSON error shape:
  - `success: false`
  - `message`
  - `data`
- API 404 responses return JSON.
- API validation errors return structured JSON.
- Unhandled API exceptions return safe JSON messages.

## CORS Configuration

`config/cors.php` is configured for Flutter/web local development origins and handles preflight (`OPTIONS`) for `api/*`.

## Local Setup

1. Install dependencies:
   - `composer install`
2. Configure environment:
   - `copy .env.example .env`
3. Generate app key:
   - `php artisan key:generate`
4. Update database credentials in `.env`:
   - `DB_CONNECTION=mysql`
   - `DB_HOST=127.0.0.1`
   - `DB_PORT=3306`
   - `DB_DATABASE=intern_track`
   - `DB_USERNAME=root`
   - `DB_PASSWORD=`
5. Run migrations:
   - `php artisan migrate`
6. Run development server:
   - `php artisan serve`
