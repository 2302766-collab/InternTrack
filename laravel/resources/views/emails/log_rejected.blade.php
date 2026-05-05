<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Your Log Needs Revision</title>
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
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
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
            background-color: #fef2f2;
            border-left: 4px solid #f5576c;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .log-details strong {
            display: block;
            color: #f5576c;
            margin-top: 10px;
        }
        .log-details strong:first-child {
            margin-top: 0;
        }
        .status-badge {
            display: inline-block;
            background-color: #fee2e2;
            color: #dc2626;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: 600;
            font-size: 14px;
            margin: 20px 0;
        }
        .comment-box {
            background-color: #fff5f5;
            border: 1px solid #fecaca;
            border-radius: 4px;
            padding: 15px;
            margin: 20px 0;
            font-style: italic;
            color: #7f1d1d;
        }
        .comment-box strong {
            display: block;
            font-style: normal;
            color: #f5576c;
            margin-bottom: 10px;
        }
        .cta-button {
            display: inline-block;
            background-color: #f5576c;
            color: white;
            padding: 12px 30px;
            text-decoration: none;
            border-radius: 4px;
            margin-top: 20px;
            font-weight: 600;
        }
        .cta-button:hover {
            background-color: #e84c3d;
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
            color: #f5576c;
        }
        .date-badge {
            display: inline-block;
            background-color: #ffe5e5;
            color: #f5576c;
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
            <h1>⚠️ Your Log Needs Revision</h1>
        </div>
        
        <div class="content">
            <p>Hello <strong>{{ $student->name ?? 'Student' }}</strong>,</p>
            
            <p>Your daily time record has been reviewed and requires revision:</p>
            
            <div class="status-badge">Status: REJECTED</div>
            
            <div class="log-details">
                <strong>Log Date:</strong> <span class="date-badge">{{ \Carbon\Carbon::parse($log->date)->format('M d, Y') }}</span>
                
                <strong>Hours Rendered:</strong> {{ $log->hours_rendered }} hour(s)
                
                <strong>Task Description:</strong>
                {{ Str::limit($log->task_description, 150) }}
                
                <strong>Reviewed By:</strong> <span class="supervisor-name">{{ $supervisorName }}</span>
                
                <strong>Review Date:</strong> {{ now()->format('M d, Y H:i A') }}
            </div>
            
            @if($comment)
            <div class="comment-box">
                <strong>Reviewer's Comment:</strong>
                {{ $comment }}
            </div>
            @endif
            
            <p>Please review the comments above and make the necessary revisions to your log entry. Once you've updated your submission, it will be sent back for review.</p>
            
            <p style="text-align: center;">
                <a href="{{ config('app.url') }}/student/logs/{{ $log->id }}" class="cta-button">Revise Log →</a>
            </p>
            
            <p style="color: #666; font-size: 14px; margin-top: 30px;">
                <strong>Questions?</strong> Please contact your supervisor <span class="supervisor-name">{{ $supervisorName }}</span> for clarification on the requested changes.
            </p>
        </div>
        
        <div class="footer">
            <p>InternTrack - Internship Management System</p>
            <p>© {{ date('Y') }} All rights reserved. This is an automated message, please do not reply.</p>
        </div>
    </div>
</body>
</html>
