param(
    [switch]$BackendOnly,
    [switch]$FlutterOnly,
    [string[]]$BackendFiles = @(),
    [string[]]$FlutterFiles = @()
)

$ErrorActionPreference = 'Stop'

if ($BackendOnly -and $FlutterOnly) {
    throw 'Choose either -BackendOnly or -FlutterOnly, not both.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-BackendTests {
    Write-Host ''
    Write-Host '==> Running Laravel automated tests' -ForegroundColor Cyan

    Push-Location (Join-Path $repoRoot 'laravel')
    try {
        $runningServices = docker compose ps --services --status running
        if (-not ($runningServices -contains 'app')) {
            throw "Laravel app container is not running. Start it with 'docker compose up -d' inside the laravel folder, then run this script again."
        }
        if (-not ($runningServices -contains 'mysql')) {
            throw "Laravel mysql container is not running. Start it with 'docker compose up -d' inside the laravel folder, then run this script again."
        }

        docker compose exec -T mysql mariadb -uroot -psecret -e "CREATE DATABASE IF NOT EXISTS interntrack_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON interntrack_test.* TO 'interntrack_user'@'%'; FLUSH PRIVILEGES;"

        $backendCommand = @('exec', 'interntrack_app', 'php', 'artisan', 'test')
        if ($BackendFiles.Count -gt 0) {
            $backendCommand += $BackendFiles
        }

        & docker $backendCommand
    }
    finally {
        Pop-Location
    }
}

function Invoke-FlutterTests {
    Write-Host ''
    Write-Host '==> Running Flutter automated tests' -ForegroundColor Cyan

    Push-Location (Join-Path $repoRoot 'flutter')
    try {
        $flutterCommand = @('test')
        if ($FlutterFiles.Count -gt 0) {
            $flutterCommand += $FlutterFiles
        }

        & flutter $flutterCommand
    }
    finally {
        Pop-Location
    }
}

Push-Location $repoRoot
try {
    if (-not $FlutterOnly) {
        Invoke-BackendTests
    }

    if (-not $BackendOnly) {
        Invoke-FlutterTests
    }

    Write-Host ''
    Write-Host 'All requested automated tests completed successfully.' -ForegroundColor Green
}
finally {
    Pop-Location
}
