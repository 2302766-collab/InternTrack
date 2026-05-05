# Email Notification System Configuration Guide

## Overview

The InternTrack application now includes a fully integrated email notification system that sends emails to supervisors and students when logs are submitted, approved, or rejected.

## Features

✅ **Asynchronous Email Delivery** - Emails are queued and processed in the background  
✅ **Three Email Templates** - Professional HTML templates for different scenarios  
✅ **Graceful Error Handling** - Failed emails are logged and can be retried  
✅ **Queue Monitoring** - Track pending and failed jobs via Laravel Artisan  

## System Architecture

### Email Types

1. **Log Pending Approval** - Sent to supervisor when student submits a log
   - Template: `resources/views/emails/log_pending_approval.blade.php`
   - Mail Class: `App\Mail\LogPendingApproval`

2. **Log Approved** - Sent to student when log is approved
   - Template: `resources/views/emails/log_approved.blade.php`
   - Mail Class: `App\Mail\LogApproved`

3. **Log Rejected** - Sent to student when log is rejected (with reason)
   - Template: `resources/views/emails/log_rejected.blade.php`
   - Mail Class: `App\Mail\LogRejected`

### Queue Configuration

The system uses Laravel's **database queue driver** by default:

```
QUEUE_CONNECTION=database
DB_QUEUE_TABLE=jobs
DB_QUEUE=default
DB_QUEUE_RETRY_AFTER=90
```

## Environment Configuration

### Development (.env)

For **development/testing** (logs emails instead of sending):

```env
MAIL_MAILER=log
QUEUE_CONNECTION=sync
```

This sends all emails to `storage/logs/laravel.log` and processes jobs synchronously.

### Staging/Production (.env)

For **staging/production** (sends real emails via SMTP):

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=your_mailtrap_username
MAIL_PASSWORD=your_mailtrap_password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="noreply@interntrack.app"
MAIL_FROM_NAME="InternTrack System"

QUEUE_CONNECTION=database
DB_QUEUE_TABLE=jobs
DB_QUEUE=default
DB_QUEUE_RETRY_AFTER=90
```

### Using Mailtrap (Testing/Staging)

1. Create a free account at https://mailtrap.io
2. Create an "Inbox" for testing
3. Copy SMTP credentials to .env
4. Use connection credentials in MAIL_HOST, MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD
5. All emails will be captured in Mailtrap inbox for verification

## Running the Queue Worker

### Development

For synchronous processing (use `QUEUE_CONNECTION=sync` in .env):
```bash
# No worker needed, emails process immediately
# Only works for 'sync' queue driver
```

### Staging/Production

For background job processing (use `QUEUE_CONNECTION=database`):

```bash
# Process jobs in background (blocks terminal)
php artisan queue:work --queue=default

# Process jobs in background (non-blocking)
php artisan queue:work --daemon

# Process specific number of jobs then exit
php artisan queue:work --max-jobs=1000

# Restart worker gracefully after each job
php artisan queue:work --max-tries=3
```

### Using Supervisor (Recommended for Production)

Create `/etc/supervisor/conf.d/interntrack-queue.conf`:

```ini
[program:interntrack-queue]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/laravel/artisan queue:work --queue=default --sleep=3 --tries=3
autostart=true
autorestart=true
stopasgroup=true
stopwaitsecs=3600
numprocs=4
redirect_stderr=true
stdout_logfile=/path/to/laravel/storage/logs/queue.log
```

Start Supervisor:
```bash
supervisorctl reread
supervisorctl update
supervisorctl start interntrack-queue:*
```

## Monitoring the Queue

### View Pending Jobs

```bash
# Count pending jobs
php artisan queue:count

# List jobs (extended package required)
php artisan queue:failed
```

### View Failed Jobs

```bash
# List failed jobs
php artisan queue:failed

# Retry a specific failed job
php artisan queue:retry {id}

# Retry all failed jobs
php artisan queue:retry all

# Delete a failed job
php artisan queue:forget {id}

# Clear all failed jobs
php artisan queue:flush
```

### Monitor in Real-time

```bash
# Watch queue status in Laravel Horizon (if installed)
php artisan horizon

# Or use the database directly
SELECT COUNT(*) FROM jobs;
SELECT COUNT(*) FROM failed_jobs;
```

## Testing Emails

### Unit Tests

Run tests for the notification service:

```bash
php artisan test tests/Unit/Services/NotificationMailServiceTest.php
```

### Integration Tests

Test the complete email flow:

```bash
php artisan test tests/Feature/EmailNotificationFlowTest.php
```

### Manual Testing

1. **Via Mailtrap:**
   - Configure Mailtrap SMTP in .env
   - Perform action (submit/approve/reject log)
   - Check Mailtrap inbox for email

2. **Via Log File:**
   - Set `MAIL_MAILER=log` in .env
   - Perform action
   - Check `storage/logs/laravel.log` for email content

3. **Via Database Queue:**
   - Set `QUEUE_CONNECTION=database` in .env
   - Start queue worker: `php artisan queue:work`
   - Perform action (submit/approve/reject log)
   - Email should be sent within 30 seconds

## Email Customization

### Modifying Templates

All email templates are located in:
```
resources/views/emails/
├── log_pending_approval.blade.php
├── log_approved.blade.php
└── log_rejected.blade.php
```

Edit these files to customize:
- Email styling
- Text content
- Call-to-action links
- Logo/branding

**Note:** Templates use inline CSS for email client compatibility.

### Modifying Mail Classes

Mail classes are located in:
```
app/Mail/
├── LogPendingApproval.php
├── LogApproved.php
└── LogRejected.php
```

Key methods:
- `envelope()` - Define subject and from address
- `content()` - Set view and data
- `attachments()` - Add file attachments

### Modifying NotificationMailService

The service is located at:
```
app/Services/NotificationMailService.php
```

Methods:
- `sendLogPendingApprovalEmail()` - Send to supervisor on log submission
- `sendLogApprovedEmail()` - Send to student on approval
- `sendLogRejectedEmail()` - Send to student on rejection

All methods queue emails to the database queue with error handling and logging.

## Troubleshooting

### Emails Not Sending

1. **Check MAIL_MAILER setting:**
   ```bash
   # Development: should be 'log' or 'smtp'
   # Production: should be 'smtp' with valid credentials
   ```

2. **Check queue worker:**
   ```bash
   # Is the queue worker running?
   ps aux | grep "queue:work"
   
   # Start it:
   php artisan queue:work
   ```

3. **Check for failed jobs:**
   ```bash
   php artisan queue:failed
   ```

4. **Check logs:**
   ```bash
   tail -f storage/logs/laravel.log
   ```

### Wrong Email Recipients

1. **Verify user email addresses:**
   ```bash
   php artisan tinker
   >>> User::find(1)->email
   ```

2. **Check database for email changes:**
   ```bash
   SELECT id, name, email FROM users WHERE role_id = 1 LIMIT 5;
   ```

### Email Template Not Rendering

1. **Verify template paths exist:**
   ```bash
   ls -la resources/views/emails/
   ```

2. **Check Blade syntax in template:**
   ```bash
   php artisan view:cache  # Pre-compile views
   php artisan view:clear  # Clear cache if errors
   ```

## Performance Considerations

- **Email Sending Time:** Typically < 1 second per email with database queue
- **Queue Processing:** Background worker processes 10-50 emails/second
- **Database Impact:** Each email queued adds 1 row to `jobs` table (removed after processing)
- **Retry Logic:** Failed emails retried up to 3 times over 90 seconds

## Security

✅ **No Database Credentials in Emails** - Only use configuration  
✅ **User Data Validation** - All email addresses validated before sending  
✅ **Rate Limiting** - Consider throttle middleware for email-heavy operations  
✅ **SSL/TLS Encryption** - Enable MAIL_ENCRYPTION in .env  
✅ **Error Logging** - All email errors logged securely  

## Dashboard Monitoring

To monitor email queue health, use this database query:

```sql
-- Count pending jobs
SELECT COUNT(*) as pending_jobs FROM jobs;

-- Count failed jobs
SELECT COUNT(*) as failed_jobs FROM failed_jobs;

-- See job details
SELECT id, queue, payload, created_at FROM jobs LIMIT 10;

-- See failed job details
SELECT id, queue, payload, failed_at FROM failed_jobs LIMIT 10;
```

## Migration and Deployment

### Required Database Tables

Run Laravel migrations to create queue tables:

```bash
# Create jobs table
php artisan queue:table
php artisan migrate

# Create failed jobs table  
php artisan queue:failed-table
php artisan migrate
```

These create:
- `jobs` table - Pending jobs
- `failed_jobs` table - Failed jobs that need retry/investigation

### Deployment Checklist

- [ ] Database migrated with queue tables
- [ ] .env configured with MAIL_MAILER and MAIL_HOST
- [ ] QUEUE_CONNECTION set to 'database' in production
- [ ] Queue worker running (via Supervisor or equivalent)
- [ ] Email templates tested and rendering correctly
- [ ] SMTP credentials validated (test with Mailtrap if needed)
- [ ] Error logs monitored (check storage/logs/)
- [ ] Failed jobs dashboard set up

## References

- [Laravel Mail Documentation](https://laravel.com/docs/mail)
- [Laravel Queues Documentation](https://laravel.com/docs/queues)
- [Mailtrap SMTP Setup](https://mailtrap.io/guide/)
- [Laravel Horizon (Advanced Queue Monitoring)](https://laravel.com/docs/horizon)
