#!/usr/bin/env php
<?php

// Quick Email Configuration Setup Script
// Run with: php artisan tinker --include=this_script.php

echo "=== InternTrack Email Configuration Setup ===\n\n";

// Check database migrations
echo "1. Checking database migrations...\n";
$database = DB::connection()->getName();
echo "   Database: $database\n";

// Check queue tables
$jobsTableExists = Schema::hasTable('jobs');
$failedJobsTableExists = Schema::hasTable('failed_jobs');

if ($jobsTableExists) {
    echo "   ✓ 'jobs' table exists\n";
} else {
    echo "   ✗ 'jobs' table missing - run: php artisan queue:table && php artisan migrate\n";
}

if ($failedJobsTableExists) {
    echo "   ✓ 'failed_jobs' table exists\n";
} else {
    echo "   ✗ 'failed_jobs' table missing - run: php artisan queue:failed-table && php artisan migrate\n";
}

// Check mail configuration
echo "\n2. Checking mail configuration...\n";
$mailMailer = config('mail.default');
$queueConnection = config('queue.default');

echo "   Mail Mailer: $mailMailer\n";
echo "   Queue Connection: $queueConnection\n";

if ($mailMailer === 'smtp') {
    $mailHost = config('mail.mailers.smtp.host');
    $mailPort = config('mail.mailers.smtp.port');
    echo "   SMTP Host: $mailHost:$mailPort\n";
    
    if (empty(config('mail.mailers.smtp.username'))) {
        echo "   ⚠ Warning: SMTP credentials not configured\n";
    } else {
        echo "   ✓ SMTP credentials configured\n";
    }
}

// Check mail views
echo "\n3. Checking email templates...\n";
$emailViewsPath = resource_path('views/emails');
$templates = [
    'log_pending_approval.blade.php',
    'log_approved.blade.php',
    'log_rejected.blade.php',
];

foreach ($templates as $template) {
    $path = "$emailViewsPath/$template";
    if (file_exists($path)) {
        echo "   ✓ $template\n";
    } else {
        echo "   ✗ $template (missing)\n";
    }
}

// Check mail classes
echo "\n4. Checking mail classes...\n";
$mailClasses = [
    'App\\Mail\\LogPendingApproval',
    'App\\Mail\\LogApproved',
    'App\\Mail\\LogRejected',
];

foreach ($mailClasses as $class) {
    if (class_exists($class)) {
        echo "   ✓ $class\n";
    } else {
        echo "   ✗ $class (missing)\n";
    }
}

// Check notification service
echo "\n5. Checking notification service...\n";
if (class_exists('App\\Services\\NotificationMailService')) {
    echo "   ✓ NotificationMailService\n";
} else {
    echo "   ✗ NotificationMailService (missing)\n";
}

// Summary
echo "\n=== Configuration Summary ===\n";
echo "Mail Driver: $mailMailer\n";
echo "Queue Driver: $queueConnection\n";
echo "Database: $database\n\n";

// Recommendations
echo "Next Steps:\n";
if (!$jobsTableExists || !$failedJobsTableExists) {
    echo "1. Run migrations: php artisan migrate\n";
}
if ($mailMailer !== 'smtp') {
    echo "2. Configure SMTP in .env for production\n";
}
if ($queueConnection === 'sync') {
    echo "3. Switch to database queue: QUEUE_CONNECTION=database in .env\n";
    echo "4. Start queue worker: php artisan queue:work\n";
}

echo "\nFor more info, see EMAIL_CONFIGURATION.md\n";
?>
