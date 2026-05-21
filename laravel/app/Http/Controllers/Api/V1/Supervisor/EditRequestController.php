<?php

namespace App\Http\Controllers\Api\V1\Supervisor;

use App\Http\Controllers\Controller;
use App\Models\DailyTimeRecord;
use App\Models\EditRequest;
use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Models\Notification;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class EditRequestController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $supervisor = $request->user();

        $requests = EditRequest::query()
            ->with([
                'requester:id,name,email',
                'logEntry.internshipProfile.student:id,name,email',
                'dailyTimeRecord.student:id,name,email',
            ])
            ->where('status', EditRequest::STATUS_PENDING)
            ->where(function ($query) use ($supervisor): void {
                $query->whereHas('logEntry.internshipProfile', function ($profileQuery) use ($supervisor): void {
                    $profileQuery->where('supervisor_id', $supervisor->id);
                })->orWhereHas('dailyTimeRecord', function ($recordQuery) use ($supervisor): void {
                    $recordQuery->whereHas('student.internshipProfile', function ($profileQuery) use ($supervisor): void {
                        $profileQuery->where('supervisor_id', $supervisor->id);
                    });
                });
            })
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Edit requests retrieved successfully.',
            'data' => $requests->map(fn (EditRequest $request) => $this->serializeEditRequest($request))->values(),
        ], 200);
    }

    public function approve(Request $request, int $id): JsonResponse
    {
        $validated = $request->validate([
            'comment' => ['nullable', 'string', 'max:2000'],
        ]);

        $editRequest = $this->findScopedRequest($request->user(), $id);

        if (! $editRequest) {
            return $this->notFound();
        }

        if ($editRequest->status !== EditRequest::STATUS_PENDING) {
            return $this->conflict('Only pending edit requests can be approved.');
        }

        try {
            DB::transaction(function () use ($editRequest, $request, $validated): void {
                if ($editRequest->resource_type === EditRequest::RESOURCE_LOG) {
                    $this->applyLogChanges($editRequest);
                } else {
                    $this->applyDtrChanges($editRequest);
                }

                $editRequest->update([
                    'status' => EditRequest::STATUS_APPROVED,
                    'reviewer_id' => $request->user()->id,
                    'review_comment' => $validated['comment'] ?? null,
                    'reviewed_at' => now(),
                ]);
            });
        } catch (\Throwable $exception) {
            report($exception);

            return response()->json([
                'success' => false,
                'message' => 'Unable to approve this edit request right now.',
                'data' => null,
            ], 500);
        }

        $editRequest->refresh()->load(['requester', 'logEntry.internshipProfile.student', 'dailyTimeRecord.student']);

        $this->notifyRequester(
            $editRequest,
            'Edit request approved',
            'Your requested correction was approved by your supervisor.',
            'EDIT_REQUEST_APPROVED'
        );

        return response()->json([
            'success' => true,
            'message' => 'Edit request approved successfully.',
            'data' => $this->serializeEditRequest($editRequest),
        ], 200);
    }

    public function reject(Request $request, int $id): JsonResponse
    {
        $validated = $request->validate([
            'comment' => ['required', 'string', 'min:3', 'max:2000'],
        ]);

        $editRequest = $this->findScopedRequest($request->user(), $id);

        if (! $editRequest) {
            return $this->notFound();
        }

        if ($editRequest->status !== EditRequest::STATUS_PENDING) {
            return $this->conflict('Only pending edit requests can be rejected.');
        }

        $editRequest->update([
            'status' => EditRequest::STATUS_REJECTED,
            'reviewer_id' => $request->user()->id,
            'review_comment' => trim($validated['comment']),
            'reviewed_at' => now(),
        ]);

        $this->notifyRequester(
            $editRequest,
            'Edit request rejected',
            'Your requested correction was rejected by your supervisor.',
            'EDIT_REQUEST_REJECTED'
        );

        return response()->json([
            'success' => true,
            'message' => 'Edit request rejected successfully.',
            'data' => $this->serializeEditRequest($editRequest->fresh([
                'requester',
                'logEntry.internshipProfile.student',
                'dailyTimeRecord.student',
            ])),
        ], 200);
    }

    private function findScopedRequest(User $supervisor, int $id): ?EditRequest
    {
        $editRequest = EditRequest::query()
            ->with(['requester', 'logEntry.internshipProfile.student', 'dailyTimeRecord.student'])
            ->find($id);

        if (! $editRequest) {
            return null;
        }

        return $this->supervisorOwnsRequest($supervisor, $editRequest)
            ? $editRequest
            : null;
    }

    private function supervisorOwnsRequest(User $supervisor, EditRequest $editRequest): bool
    {
        if ($editRequest->resource_type === EditRequest::RESOURCE_LOG) {
            return (int) $editRequest->logEntry?->internshipProfile?->supervisor_id === (int) $supervisor->id;
        }

        $studentId = $editRequest->dailyTimeRecord?->student_id;
        if (! $studentId) {
            return false;
        }

        return InternshipProfile::query()
            ->where('student_id', $studentId)
            ->where('supervisor_id', $supervisor->id)
            ->exists();
    }

    private function applyLogChanges(EditRequest $editRequest): void
    {
        $log = $editRequest->logEntry;
        $changes = $editRequest->requested_changes ?? [];

        if (! $log instanceof LogEntry) {
            throw new \RuntimeException('Missing target log entry for edit request.');
        }

        $log->update([
            'date' => $changes['date'] ?? $log->date,
            'hours_rendered' => (int) ($changes['hours_rendered'] ?? $log->hours_rendered),
            'task_description' => $changes['task_description'] ?? $log->task_description,
            'status' => 'APPROVED',
        ]);
    }

    private function applyDtrChanges(EditRequest $editRequest): void
    {
        $record = $editRequest->dailyTimeRecord;
        $changes = $editRequest->requested_changes ?? [];

        if (! $record instanceof DailyTimeRecord) {
            throw new \RuntimeException('Missing target daily time record for edit request.');
        }

        $timeIn = $this->parseNullableCarbon($changes['time_in_at'] ?? null);
        $lunchOut = $this->parseNullableCarbon($changes['lunch_out_at'] ?? null);
        $lunchIn = $this->parseNullableCarbon($changes['lunch_in_at'] ?? null);
        $timeOut = $this->parseNullableCarbon($changes['time_out_at'] ?? null);

        $firstMinutes = $this->segmentMinutes($timeIn, $lunchOut);
        $secondMinutes = $this->segmentMinutes($lunchIn, $timeOut);

        $record->update([
            'time_in_at' => $timeIn,
            'lunch_out_at' => $lunchOut,
            'lunch_in_at' => $lunchIn,
            'time_out_at' => $timeOut,
            'first_work_minutes' => $firstMinutes,
            'second_work_minutes' => $secondMinutes,
            'total_work_minutes' => $firstMinutes + $secondMinutes,
            'status' => 'COMPLETED',
        ]);
    }

    private function parseNullableCarbon(mixed $value): ?Carbon
    {
        if ($value === null || trim((string) $value) === '') {
            return null;
        }

        return Carbon::parse($value);
    }

    private function segmentMinutes(?Carbon $start, ?Carbon $end): int
    {
        if ($start === null || $end === null) {
            return 0;
        }

        return max(0, $start->diffInMinutes($end));
    }

    private function notifyRequester(
        EditRequest $editRequest,
        string $title,
        string $message,
        string $type
    ): void {
        Notification::query()->create([
            'user_id' => $editRequest->requester_id,
            'title' => $title,
            'message' => $message,
            'type' => $type,
            'meta' => [
                'edit_request_id' => $editRequest->id,
                'resource_type' => $editRequest->resource_type,
                'resource_id' => $editRequest->resource_type === EditRequest::RESOURCE_LOG
                    ? $editRequest->log_entry_id
                    : $editRequest->daily_time_record_id,
            ],
            'is_read' => false,
        ]);
    }

    private function serializeEditRequest(EditRequest $editRequest): array
    {
        $student = $editRequest->resource_type === EditRequest::RESOURCE_LOG
            ? $editRequest->logEntry?->internshipProfile?->student
            : $editRequest->dailyTimeRecord?->student;

        $currentValues = $editRequest->resource_type === EditRequest::RESOURCE_LOG
            ? [
                'date' => $editRequest->logEntry?->date,
                'hours_rendered' => $editRequest->logEntry?->hours_rendered,
                'task_description' => $editRequest->logEntry?->task_description,
                'status' => $editRequest->logEntry?->status,
            ]
            : [
                'date' => $editRequest->dailyTimeRecord?->date?->toDateString(),
                'time_in_at' => $editRequest->dailyTimeRecord?->time_in_at?->toIso8601String(),
                'lunch_out_at' => $editRequest->dailyTimeRecord?->lunch_out_at?->toIso8601String(),
                'lunch_in_at' => $editRequest->dailyTimeRecord?->lunch_in_at?->toIso8601String(),
                'time_out_at' => $editRequest->dailyTimeRecord?->time_out_at?->toIso8601String(),
                'total_work_minutes' => $editRequest->dailyTimeRecord?->total_work_minutes,
                'status' => $editRequest->dailyTimeRecord?->status,
            ];

        return [
            'id' => $editRequest->id,
            'resource_type' => $editRequest->resource_type,
            'resource_id' => $editRequest->resource_type === EditRequest::RESOURCE_LOG
                ? $editRequest->log_entry_id
                : $editRequest->daily_time_record_id,
            'status' => $editRequest->status,
            'reason' => $editRequest->reason,
            'review_comment' => $editRequest->review_comment,
            'reviewed_at' => $editRequest->reviewed_at,
            'created_at' => $editRequest->created_at,
            'requester' => [
                'id' => $editRequest->requester?->id,
                'name' => $editRequest->requester?->name,
                'email' => $editRequest->requester?->email,
            ],
            'student' => [
                'id' => $student?->id,
                'name' => $student?->name,
                'email' => $student?->email,
            ],
            'current_values' => $currentValues,
            'requested_changes' => $editRequest->requested_changes ?? [],
        ];
    }

    private function notFound(): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => 'Edit request not found.',
            'data' => null,
        ], 404);
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
