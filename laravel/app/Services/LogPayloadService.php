<?php

namespace App\Services;

use App\Models\Attachment;
use App\Models\LogAction;
use App\Models\LogEntry;

class LogPayloadService
{
    public function forStudent(LogEntry $log): array
    {
        return [
            'id' => $log->id,
            'internship_profile_id' => $log->internship_profile_id,
            'date' => $log->date,
            'hours_rendered' => $log->hours_rendered,
            'task_description' => $log->task_description,
            'status' => $log->status,
            'submitted_at' => $log->submitted_at,
            'created_at' => $log->created_at,
            'updated_at' => $log->updated_at,
            'attachments' => $this->attachmentPayload($log),
            'review_history' => $this->reviewHistoryPayload($log),
        ];
    }

    public function forReviewer(LogEntry $log): array
    {
        $profile = $log->internshipProfile;

        return [
            'id' => $log->id,
            'internship_profile_id' => $log->internship_profile_id,
            'student' => [
                'name' => $profile?->student?->name,
                'email' => $profile?->student?->email,
            ],
            'company_name' => $profile?->company_name,
            'date' => $log->date,
            'hours_rendered' => $log->hours_rendered,
            'task_description' => $log->task_description,
            'status' => $log->status,
            'submitted_at' => $log->submitted_at,
            'attachments' => $this->attachmentPayload($log),
            'review_history' => $this->reviewHistoryPayload($log),
        ];
    }

    private function attachmentPayload(LogEntry $log): array
    {
        return $log->attachments
            ->map(function (Attachment $attachment) {
                return [
                    'id' => $attachment->id,
                    'file_path' => $attachment->file_path,
                    'file_type' => $attachment->file_type,
                    'file_size' => $attachment->file_size,
                    'created_at' => $attachment->created_at,
                ];
            })
            ->values()
            ->all();
    }

    private function reviewHistoryPayload(LogEntry $log): array
    {
        return $log->logActions
            ->map(function (LogAction $action) {
                return [
                    'id' => $action->id,
                    'action' => $action->action,
                    'comment' => $action->comment,
                    'acted_at' => $action->acted_at,
                    'supervisor' => [
                        'id' => $action->supervisor?->id,
                        'name' => $action->supervisor?->name,
                        'email' => $action->supervisor?->email,
                    ],
                ];
            })
            ->values()
            ->all();
    }
}
