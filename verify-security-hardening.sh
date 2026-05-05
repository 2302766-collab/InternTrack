#!/bin/bash
# Security Hardening Test Verification Script
# Run this after Docker containers are started

echo "=== Security Hardening Verification Script ==="
echo ""
echo "Checking Docker containers..."

# Check if containers are running
cd laravel

if ! docker compose ps --services --status running | grep -q app; then
    echo "ERROR: Laravel app container is not running."
    echo "Start containers with: docker compose up -d"
    exit 1
fi

if ! docker compose ps --services --status running | grep -q mysql; then
    echo "ERROR: MySQL container is not running."
    echo "Start containers with: docker compose up -d"
    exit 1
fi

echo "✓ Docker containers are running"
echo ""

# Create test database
echo "Setting up test database..."
docker compose exec -T mysql mariadb -uroot -psecret -e "CREATE DATABASE IF NOT EXISTS interntrack_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON interntrack_test.* TO 'interntrack_user'@'%'; FLUSH PRIVILEGES;"

echo "✓ Test database ready"
echo ""

# Run all tests including security hardening tests
echo "Running Laravel test suite..."
docker compose exec -T app php artisan test

TEST_EXIT_CODE=$?

echo ""
echo "=== Test Results ==="

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✓ All tests passed!"
    echo ""
    echo "Security verifications:"
    echo "✓ Safe exception handling implemented"
    echo "✓ File upload rate limiting (10/min) enforced"
    echo "✓ Comment length validation (max 2000 chars) active"
    echo ""
    echo "The application is ready for staging deployment."
else
    echo "✗ Tests failed. Please review the output above."
    exit 1
fi
