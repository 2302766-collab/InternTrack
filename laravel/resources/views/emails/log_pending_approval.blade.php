<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>New Log Submitted for Review</title>
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
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
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
            background-color: #f9f9f9;
            border-left: 4px solid #667eea;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .log-details strong {
            display: block;
            color: #667eea;
            margin-top: 10px;
        }
        .log-details strong:first-child {
            margin-top: 0;
        }
        .cta-button {
            display: inline-block;
            background-color: #667eea;
            color: white;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 4px;
            margin-top: 20px;
            font-weight: 600;
        }
        .cta-button:hover {
            background-color: #5568d3;
        }
        .footer {
            background-color: #f4f4f4;
            padding: 20px;
            text-align: center;
            font-size: 12px;
            color: #666;
            border-top: 1px solid #ddd;
        }
        .student-name {
            font-weight: 600;
            color: #667eea;
        }
        .date-badge {
            display: inline-block;
            background-color: #e8eaf6;
            color: #667eea;
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
            <h1>📋 New Log Submitted for Review</h1>
        </div>
        
        <div class="content">
            <p>Hello <strong>{{ $supervisor->name }}</strong>,</p>
            
            <p>A new daily time record (log) has been submitted for your review:</p>
            
            <div class="log-details">
                <strong>Student:</strong> {{ $student->name ?? 'Unknown' }}
                
                <strong>Log Date:</strong> <span class="date-badge">{{ \Carbon\Carbon::parse($log->date)->format('M d, Y') }}</span>
                
                <strong>Hours Rendered:</strong> {{ $log->hours_rendered }} hour(s)
                
                <strong>Task Description:</strong>
                {{ Str::limit($log->task_description, 150) }}
                
                <strong>Submitted:</strong> {{ $log->submitted_at?->format('M d, Y H:i A') ?? 'N/A' }}
            </div>
            
            <p>Please review this log entry and approve or reject it as needed. If additional information is required, you can add comments during the review process.</p>
            
            <p style="text-align: center;">
                <a href="{{ config('app.url') }}/supervisor/logs" class="cta-button">Review Log →</a>
            </p>
            
            <p style="color: #666; font-size: 14px; margin-top: 30px;">
                <strong>Note:</strong> Please review logs within 48 hours to keep the process moving smoothly.
            </p>
        </div>
        
        <div class="footer">
            <p>InternTrack - Internship Management System</p>
            <p>© {{ date('Y') }} All rights reserved. This is an automated message, please do not reply.</p>
        </div>
    </div>
</body>
</html>
