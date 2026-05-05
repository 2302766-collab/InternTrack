<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Your Log Has Been Approved</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f4f4f4;
            margin: 0;
            padding: 0;
        }
        .email-container {
            max-width: 600px;
            margin: 20px auto;
            background-color: #ffffff;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
            color: white;
            padding: 30px 20px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 300;
        }
        .content {
            padding: 30px;
        }
        .content p {
            margin: 0 0 15px 0;
        }
        .log-details {
            background-color: #f0fdf4;
            border-left: 4px solid #11998e;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .log-details strong {
            display: block;
            color: #11998e;
            margin-top: 10px;
        }
        .log-details strong:first-child {
            margin-top: 0;
        }
        .success-badge {
            display: inline-block;
            background-color: #d1fae5;
            color: #047857;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: 600;
            font-size: 14px;
            margin: 20px 0;
        }
        .cta-button {
            display: inline-block;
            background-color: #11998e;
            color: white;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 4px;
            margin-top: 20px;
            font-weight: 600;
        }
        .cta-button:hover {
            background-color: #0d7a72;
        }
        .footer {
            background-color: #f4f4f4;
            padding: 20px;
            text-align: center;
            font-size: 12px;
            color: #666;
            border-top: 1px solid #ddd;
        }
        .supervisor-name {
            font-weight: 600;
            color: #11998e;
        }
        .date-badge {
            display: inline-block;
            background-color: #e0f2f1;
            color: #11998e;
            padding: 4px 12px;
            border-radius: 20px;
            font-weight: 600;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="email-container">
        <div class="header">
            <h1>✓ Your Log Has Been Approved</h1>
        </div>
        
        <div class="content">
            <p>Hello <strong>{{ $student->name ?? 'Student' }}</strong>,</p>
            
            <p>Great news! Your daily time record has been approved:</p>
            
            <div class="success-badge">Status: APPROVED</div>
            
            <div class="log-details">
                <strong>Log Date:</strong> <span class="date-badge">{{ \Carbon\Carbon::parse($log->date)->format('M d, Y') }}</span>
                
                <strong>Hours Rendered:</strong> {{ $log->hours_rendered }} hour(s)
                
                <strong>Task Description:</strong>
                {{ Str::limit($log->task_description, 150) }}
                
                <strong>Approved By:</strong> <span class="supervisor-name">{{ $supervisorName }}</span>
                
                <strong>Approval Date:</strong> {{ now()->format('M d, Y H:i A') }}
            </div>
            
            <p>Your log entry has been successfully reviewed and approved. These hours have been recorded towards your internship requirements.</p>
            
            <p style="text-align: center;">
                <a href="{{ config('app.url') }}/student/logs" class="cta-button">View All Logs →</a>
            </p>
            
            <p style="color: #666; font-size: 14px; margin-top: 30px;">
                <strong>Thank you</strong> for your diligent work and timely submissions. Keep up the excellent progress!
            </p>
        </div>
        
        <div class="footer">
            <p>InternTrack - Internship Management System</p>
            <p>© {{ date('Y') }} All rights reserved. This is an automated message, please do not reply.</p>
        </div>
    </div>
</body>
</html>
