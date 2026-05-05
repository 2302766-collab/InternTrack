<?php

namespace App\Services;

use App\Models\LogEntry;
use App\Models\User;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;
use Illuminate\Mail\Mailable;

class NotificationMailService
{
    /**
     * Send email notification when a log is submitted for supervisor review
     */
    public function sendLogPendingApprovalEmail(LogEntry $log, User $supervisor): void
    {
        try {
            $student = $log->internshipProfile?->student;
            
            if (!$student) {
                Log::warning('Cannot send log pending approval email: student not found', [
                    'log_id' => $log->id,
                ]);
                return;
            }

            $mailable = new \App\Mail\LogPendingApproval($log, $supervisor);
            
            Mail::to($supervisor->email)->queue($mailable)
                ->onConnection('database')
                ->onQueue('default');

            Log::info('Log pending approval email queued', [
                'log_id' => $log->id,
                'supervisor_id' => $supervisor->id,
                'supervisor_email' => $supervisor->email,
            ]);
        } catch (\Throwable $exception) {
            Log::error('Failed to queue log pending approval email', [
                'log_id' => $log->id,
                'supervisor_id' => $supervisor->id,
                'error' => $exception->getMessage(),
            ]);
        }
    }

    /**
     * Send email notification when a log is approved
     */
    public function sendLogApprovedEmail(LogEntry $log, string $supervisorName): void
    {
        try {
            $student = $log->internshipProfile?->student;
            
            if (!$student) {
                Log::warning('Cannot send log approved email: student not found', [
                    'log_id' => $log->id,
                ]);
                return;
            }

            $mailable = new \App\Mail\LogApproved($log, $supervisorName);
            
            Mail::to($student->email)->queue($mailable)
                ->onConnection('database')
                ->onQueue('default');

            Log::info('Log approved email queued', [
                'log_id' => $log->id,
                'student_id' => $student->id,
                'student_email' => $student->email,
            ]);
        } catch (\Throwable $exception) {
            Log::error('Failed to queue log approved email', [
                'log_id' => $log->id,
                'error' => $exception->getMessage(),
            ]);
        }
    }

    /**
     * Send email notification when a log is rejected
     */
    public function sendLogRejectedEmail(LogEntry $log, string $supervisorName, ?string $comment): void
    {
        try {
            $student = $log->internshipProfile?->student;
            
            if (!$student) {
                Log::warning('Cannot send log rejected email: student not found', [
                    'log_id' => $log->id,
                ]);
                return;
            }

            $mailable = new \App\Mail\LogRejected($log, $supervisorName, $comment);
            
            Mail::to($student->email)->queue($mailable)
                ->onConnection('database')
                ->onQueue('default');

            Log::info('Log rejected email queued', [
                'log_id' => $log->id,
                'student_id' => $student->id,
                'student_email' => $student->email,
            ]);
        } catch (\Throwable $exception) {
            Log::error('Failed to queue log rejected email', [
                'log_id' => $log->id,
                'error' => $exception->getMessage(),
            ]);
        }
    }
}
