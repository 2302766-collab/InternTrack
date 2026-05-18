<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Http\Controllers\Controller;
use App\Models\DailyTimeRecord;
use App\Models\EditRequest;
use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Notification;
use App\Models\Role;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EditRequestController extends Controller
{
    public function requestLogEdit(Request $request, int $id): JsonResponse
    {
        $student = $request->user();

        $profile = InternshipProfile::query()
            ->where('student_id', $student->id)
            ->first();

        if (! $profile) {
            return $this->notFound('Internship profile is required before requesting log edits.');
        }

        $log = LogEntry::query()->find($id);

        if (! $log) {
            return $this->notFound('Log not found.');
        }

        if ($log->internship_profile_id !== $profile->id) {
            return $this->forbidden('You are not allowed to request edits for this log.');
        }

        if ($this->hasPendingLogRequest($log->id)) {
            return $this->conflict('A pending edit request already exists for this log.');
        }

        $validated = $request->validate([
            'date' => ['required', 'date'],
            'hours_rendered' => ['required', 'integer', 'min:1', 'max:12'],
            'task_description' => ['required', 'string'],
            'reason' => ['required', 'string', 'min:5', 'max:2000'],
        ]);

        $editRequest = EditRequest::query()->create([
            'requester_id' => $student->id,
            'resource_type' => EditRequest::RESOURCE_LOG,
            'log_entry_id' => $log->id,
            'status' => EditRequest::STATUS_PENDING,
            'reason' => trim($validated['reason']),
            'requested_changes' => [
                'date' => Carbon::parse($validated['date'])->toDateString(),
                'hours_rendered' => (int) $validated['hours_rendered'],
                'task_description' => trim($validated['task_description']),
            ],
        ]);

        $editRequest->load(['requester', 'logEntry.internshipProfile.student']);

        $this->notifyAdmins(
            title: 'Log edit request submitted',
            message: "{$student->name} requested a correction for log #{$log->id}.",
            type: 'EDIT_REQUEST_SUBMITTED',
            meta: [
                'edit_request_id' => $editRequest->id,
                'resource_type' => EditRequest::RESOURCE_LOG,
                'log_entry_id' => $log->id,
            ],
        );

        return response()->json([
            'success' => true,
            'message' => 'Log edit request submitted successfully.',
            'data' => $this->serializeEditRequest($editRequest),
        ], 201);
    }

    public function requestDtrEdit(Request $request): JsonResponse
    {
        $student = $request->user();

        $validated = $request->validate([
            'daily_time_record_id' => ['required', 'integer'],
            'time_in_at' => ['required', 'date'],
            'lunch_out_at' => ['required', 'date'],
            'lunch_in_at' => ['required', 'date'],
            'time_out_at' => ['required', 'date'],
            'reason' => ['required', 'string', 'min:5', 'max:2000'],
        ]);

        $record = DailyTimeRecord::query()->find($validated['daily_time_record_id']);

        if (! $record) {
            return $this->notFound('Daily time record not found.');
        }

        if ((int) $record->student_id !== (int) $student->id) {
            return $this->forbidden('You are not allowed to request edits for this daily time record.');
        }

        if ($record->status !== 'COMPLETED') {
            return $this->conflict('Only completed daily time records can be submitted for admin correction.');
        }

        if ($this->hasPendingDtrRequest($record->id)) {
            return $this->conflict('A pending edit request already exists for this daily time record.');
        }

        $requestedChanges = [
            'time_in_at' => Carbon::parse($validated['time_in_at']),
            'lunch_out_at' => Carbon::parse($validated['lunch_out_at']),
            'lunch_in_at' => Carbon::parse($validated['lunch_in_at']),
            'time_out_at' => Carbon::parse($validated['time_out_at']),
        ];

        if (! $this->isValidDtrSequence($record->date->toDateString(), $requestedChanges)) {
            return response()->json([
                'success' => false,
                'message' => 'Requested DTR times must stay in order and match the record date.',
                'data' => [
                    'errors' => [
                        'time_sequence' => ['Requested DTR times must stay in order and match the record date.'],
                    ],
                ],
            ], 422);
        }

        $editRequest = EditRequest::query()->create([
            'requester_id' => $student->id,
            'resource_type' => EditRequest::RESOURCE_DTR,
            'daily_time_record_id' => $record->id,
            'status' => EditRequest::STATUS_PENDING,
            'reason' => trim($validated['reason']),
            'requested_changes' => [
                'date' => $record->date->toDateString(),
                'time_in_at' => $requestedChanges['time_in_at']->toIso8601String(),
                'lunch_out_at' => $requestedChanges['lunch_out_at']->toIso8601String(),
                'lunch_in_at' => $requestedChanges['lunch_in_at']->toIso8601String(),
                'time_out_at' => $requestedChanges['time_out_at']->toIso8601String(),
            ],
        ]);

        $editRequest->load(['requester', 'dailyTimeRecord.student']);

        $this->notifyAdmins(
            title: 'DTR edit request submitted',
            message: "{$student->name} requested a correction for DTR #{$record->id}.",
            type: 'EDIT_REQUEST_SUBMITTED',
            meta: [
                'edit_request_id' => $editRequest->id,
                'resource_type' => EditRequest::RESOURCE_DTR,
                'daily_time_record_id' => $record->id,
            ],
        );

        return response()->json([
            'success' => true,
            'message' => 'DTR edit request submitted successfully.',
            'data' => $this->serializeEditRequest($editRequest),
        ], 201);
    }

    private function hasPendingLogRequest(int $logId): bool
    {
        return EditRequest::query()
            ->where('resource_type', EditRequest::RESOURCE_LOG)
            ->where('log_entry_id', $logId)
            ->where('status', EditRequest::STATUS_PENDING)
            ->exists();
    }

    private function hasPendingDtrRequest(int $recordId): bool
    {
        return EditRequest::query()
            ->where('resource_type', EditRequest::RESOURCE_DTR)
            ->where('daily_time_record_id', $recordId)
            ->where('status', EditRequest::STATUS_PENDING)
            ->exists();
    }

    private function isValidDtrSequence(string $expectedDate, array $changes): bool
    {
        $timeIn = $changes['time_in_at'];
        $lunchOut = $changes['lunch_out_at'];
        $lunchIn = $changes['lunch_in_at'];
        $timeOut = $changes['time_out_at'];

        $sameDate = $timeIn->toDateString() === $expectedDate
            && $lunchOut->toDateString() === $expectedDate
            && $lunchIn->toDateString() === $expectedDate
            && $timeOut->toDateString() === $expectedDate;

        if (! $sameDate) {
            return false;
        }

        return $timeIn->lt($lunchOut)
            && $lunchOut->lt($lunchIn)
            && $lunchIn->lt($timeOut);
    }

    private function notifyAdmins(
        string $title,
        string $message,
        string $type,
        array $meta
    ): void {
        $adminRoleId = Role::query()->where('name', 'Admin')->value('id');
        if (! $adminRoleId) {
            return;
        }

        User::query()
            ->where('role_id', $adminRoleId)
            ->get(['id'])
            ->each(function (User $admin) use ($title, $message, $type, $meta): void {
                Notification::query()->create([
                    'user_id' => $admin->id,
                    'title' => $title,
                    'message' => $message,
                    'type' => $type,
                    'meta' => $meta,
                    'is_read' => false,
                ]);
            });
    }

    private function serializeEditRequest(EditRequest $editRequest): array
    {
        $resource = $editRequest->resource_type === EditRequest::RESOURCE_LOG
            ? $editRequest->logEntry
            : $editRequest->dailyTimeRecord;

        return [
            'id' => $editRequest->id,
            'resource_type' => $editRequest->resource_type,
            'resource_id' => $resource?->id,
            'status' => $editRequest->status,
            'reason' => $editRequest->reason,
            'requested_changes' => $editRequest->requested_changes ?? [],
            'review_comment' => $editRequest->review_comment,
            'reviewed_at' => $editRequest->reviewed_at,
            'created_at' => $editRequest->created_at,
        ];
    }

    private function notFound(string $message): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => $message,
            'data' => null,
        ], 404);
    }

    private function forbidden(string $message): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => $message,
            'data' => null,
        ], 403);
    }

    private function conflict(string $message): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => $message,
            'data' => null,
        ], 409);
    }
}
