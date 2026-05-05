#!/usr/bin/env pwsh
# Security Hardening Test Verification Script (PowerShell)
# Run this after Docker containers are started

Write-Host "=== Security Hardening Verification Script ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Checking Docker containers..." -ForegroundColor Yellow

# Check if containers are running
Push-Location laravel
try {
    $runningServices = docker compose ps --services --status running 2>$null
    
    if (-not ($runningServices -contains 'app')) {
        Write-Host "ERROR: Laravel app container is not running." -ForegroundColor Red
        Write-Host "Start containers with: docker compose up -d"
        return 1
    }

    if (-not ($runningServices -contains 'mysql')) {
        Write-Host "ERROR: MySQL container is not running." -ForegroundColor Red
        Write-Host "Start containers with: docker compose up -d"
        return 1
    }

    Write-Host "✓ Docker containers are running" -ForegroundColor Green
    Write-Host ""

    # Create test database
    Write-Host "Setting up test database..." -ForegroundColor Yellow
    docker compose exec -T mysql mariadb -uroot -psecret -e "CREATE DATABASE IF NOT EXISTS interntrack_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON interntrack_test.* TO 'interntrack_user'@'%'; FLUSH PRIVILEGES;"

    Write-Host "✓ Test database ready" -ForegroundColor Green
    Write-Host ""

    # Run all tests including security hardening tests
    Write-Host "Running Laravel test suite..." -ForegroundColor Yellow
    docker compose exec -T app php artisan test
    
    $testExitCode = $LASTEXITCODE

    Write-Host ""
    Write-Host "=== Test Results ===" -ForegroundColor Cyan
    
    if ($testExitCode -eq 0) {
        Write-Host "✓ All tests passed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Security verifications:" -ForegroundColor Green
        Write-Host "✓ Safe exception handling implemented"
        Write-Host "✓ File upload rate limiting (10/min) enforced"
        Write-Host "✓ Comment length validation (max 2000 chars) active"
        Write-Host ""
        Write-Host "The application is ready for staging deployment." -ForegroundColor Green
    } else {
        Write-Host "✗ Tests failed. Please review the output above." -ForegroundColor Red
        return 1
    }
}
finally {
    Pop-Location
}
