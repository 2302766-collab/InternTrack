#!/bin/sh
set -eu

cd /var/www

if [ ! -f .env ]; then
    echo "Environment file missing; copying from .env.example..."
    cp .env.example .env
fi

db_host="${DB_HOST:-mysql}"
db_port="${DB_PORT:-3306}"
db_name="${DB_DATABASE:-interntrack}"
db_user="${DB_USERNAME:-interntrack_user}"
db_pass="${DB_PASSWORD:-secret}"

echo "Waiting for database at ${db_host}:${db_port}..."

attempt=0
until php -r '
$dsn = sprintf(
    "mysql:host=%s;port=%s;dbname=%s",
    getenv("DB_HOST") ?: "mysql",
    getenv("DB_PORT") ?: "3306",
    getenv("DB_DATABASE") ?: "interntrack"
);
new PDO($dsn, getenv("DB_USERNAME") ?: "interntrack_user", getenv("DB_PASSWORD") ?: "secret");
' >/dev/null 2>&1; do
    attempt=$((attempt + 1))

    if [ "$attempt" -ge 60 ]; then
        echo "Database did not become ready in time." >&2
        exit 1
    fi

    sleep 2
done

echo "Database is ready."

if [ ! -f vendor/autoload.php ]; then
    echo "Composer dependencies are missing; installing..."
    composer install
fi

# Package discovery/cache files can outlive dependency changes inside the
# persisted Docker volume and block Artisan before the app server starts.
if [ -f bootstrap/cache/packages.php ] || [ -f bootstrap/cache/services.php ]; then
    echo "Clearing cached Laravel service manifests..."
    rm -f bootstrap/cache/packages.php bootstrap/cache/services.php
fi

if [ "${AUTO_MIGRATE_AND_SEED:-true}" != "false" ]; then
    echo "Running migrations..."
    php artisan migrate --force

    echo "Ensuring development seed data exists..."
    php artisan db:seed --force
else
    echo "Skipping migrations and seeders because AUTO_MIGRATE_AND_SEED=false."
fi

echo "Starting Laravel development server..."
exec php -S 0.0.0.0:8000 -t public server.php
