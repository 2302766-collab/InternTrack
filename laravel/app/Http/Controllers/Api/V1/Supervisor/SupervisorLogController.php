<?php

namespace App\Http\Controllers\Api\V1\Supervisor;

use App\Http\Controllers\Controller;
use App\Models\Attachment;
use App\Models\InternshipProfile;
use App\Models\LogAction;
use App\Models\LogEntry;
use App\Models\Notification;
use App\Services\AttachmentFileService;
use App\Services\LogPayloadService;
use App\Services\NotificationMailService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SupervisorLogController extends Controller
{
    public function __construct(
        private readonly LogPayloadService $logPayloads,
        private readonly AttachmentFileService $attachmentFiles,
        private readonly NotificationMailService $notificationMailService,
    ) {
    }

    public function index(Request $request)
    {
        $supervisorId = $request->user()->id;

        $profileIds = InternshipProfile::where('supervisor_id', $supervisorId)
            ->pluck('id');

        if ($profileIds->isEmpty()) {
            return response()->json([
                'success' => true,
                'message' => 'Logs retrieved successfully.',
                'data' => [],
            ], 200);
        }

        // Eager load all needed relations to prevent N+1 queries
        // This reduces queries from N+1 to ~3 total: 1 for logs, 1 for profiles+students, 1 for attachments count
        $logs = LogEntry::query()
            ->with(['internshipProfile.student', 'attachments', 'logActions.supervisor'])
            ->withCount('attachments')
            ->whereIn('internship_profile_id', $profileIds)
            ->where('status', 'PENDING')
            ->orderBy('date', 'asc')
            ->orderBy('id', 'asc')
            ->get([
                'id',
                'internship_profile_id',
                'date',
                'hours_rendered',
                'task_description',
                'status',
                'submitted_at',
            ]);

        $data = $logs->map(function (LogEntry $log) {
            return [
                'id' => $log->id,
                'internship_profile_id' => $log->internship_profile_id,
                'student_name' => $log->internshipProfile?->student?->name,
                'date' => $log->date,
                'hours_rendered' => $log->hours_rendered,
                'task_description' => $log->task_description,
                'status' => $log->status,
                'submitted_at' => $log->submitted_at,
                'attachments_count' => $log->attachments_count ?? 0,
                'has_attachments' => ($log->attachments_count ?? 0) > 0,
            ];
        })->values();

        return response()->json([
            'success' => true,
            'message' => 'Logs retrieved successfully.',
            'data' => $data,
        ], 200);
    }

    public function show(Request $request, int $id)
    {
        $supervisorId = $request->user()->id;

        $log = LogEntry::with(['attachments', 'internshipProfile.student', 'logActions.supervisor'])
            ->find($id);

        if (!$log) {
            return response()->json([
                'success' => false,
                'message' => 'Log not found.',
                'data' => null,
            ], 404);
        }

        $profile = $log->internshipProfile;

        if (!$profile || $profile->supervisor_id !== $supervisorId) {
            return response()->json([
                'success' => false,
                'message' => 'You are not allowed to access this log.',
                'data' => null,
            ], 403);
        }

        return response()->json([
            'success' => true,
            'message' => 'Log retrieved successfully.',
            'data' => $this->logPayloads->forReviewer($log),
        ], 200);
    }

    public function approve(Request $request, int $id)
    {
        return $this->review(
            request: $request,
            id: $id,
            targetStatus: 'APPROVED',
            successMessage: 'Log approved successfully.',
            forbiddenMessage: 'You are not allowed to approve this log.',
            conflictMessage: 'Only PENDING logs can be approved.',
            commentRequired: false,
        );
    }

    public function reject(Request $request, int $id)
    {
        return $this->review(
            request: $request,
            id: $id,
            targetStatus: 'REJECTED',
            successMessage: 'Log rejected successfully.',
            forbiddenMessage: 'You are not allowed to reject this log.',
            conflictMessage: 'Only PENDING logs can be rejected.',
            commentRequired: true,
        );
    }

    public function downloadAttachment(Request $request, int $id, int $attachmentId)
    {
        $supervisorId = $request->user()->id;

        $log = LogEntry::with('internshipProfile')->find($id);

        if (!$log) {
            return response()->json([
                'success' => false,
                'message' => 'Log not found.',
                'data' => null,
            ], 404);
        }

        $profile = $log->internshipProfile;

        if (!$profile || $profile->supervisor_id !== $supervisorId) {
            return response()->json([
                'success' => false,
                'message' => 'You are not allowed to access this log attachment.',
                'data' => null,
            ], 403);
        }

        $attachment = Attachment::where('id', $attachmentId)
            ->where('log_entry_id', $log->id)
            ->first();

        if (!$attachment) {
            return response()->json([
                'success' => false,
                'message' => 'Attachment not found.',
                'data' => null,
            ], 404);
        }

        if (!$this->attachmentFiles->exists($attachment)) {
            return response()->json([
                'success' => false,
                'message' => 'Attachment file is missing.',
                'data' => null,
            ], 404);
        }

        return $this->attachmentFiles->inlineResponse($attachment);
    }

    private function review(
        Request $request,
        int $id,
        string $targetStatus,
        string $successMessage,
        string $forbiddenMessage,
        string $conflictMessage,
        bool $commentRequired,
    ) {
        if ($request->has('comment')) {
            $comment = trim((string) $request->input('comment'));
            $request->merge([
                'comment' => $comment === '' ? null : $comment,
            ]);
        }

        if ($commentRequired && !$request->filled('comment')) {
            return response()->json([
                'success' => false,
                'message' => 'Rejection comment is required.',
                'data' => [
                    'errors' => [
                        'comment' => ['Rejection comment is required.'],
                    ],
                ],
            ], 422);
        }

        $commentRules = [
            $commentRequired ? 'required' : 'nullable',
            'string',
            'max:2000',
        ];

        if ($commentRequired) {
            $commentRules[] = 'min:3';
        }

        $validated = $request->validate([
            'comment' => $commentRules,
            'action' => ['nullable', Rule::in(['APPROVED', 'REJECTED'])],
        ]);

        $supervisorId = $request->user()->id;

        $log = LogEntry::with(['attachments', 'internshipProfile.student', 'logActions.supervisor'])
            ->find($id);

        if (!$log) {
            return response()->json([
                'success' => false,
                'message' => 'Log not found.',
                'data' => null,
            ], 404);
        }

        $profile = $log->internshipProfile;

        if (!$profile || $profile->supervisor_id !== $supervisorId) {
            return response()->json([
                'success' => false,
                'message' => $forbiddenMessage,
                'data' => null,
            ], 403);
        }

        if ($log->status !== 'PENDING') {
            return response()->json([
                'success' => false,
                'message' => $conflictMessage,
                'data' => null,
            ], 409);
        }

        $comment = $validated['comment'] ?? null;

        $log->update([
            'status' => $targetStatus,
        ]);

        LogAction::create([
            'log_entry_id' => $log->id,
            'supervisor_id' => $supervisorId,
            'action' => $targetStatus,
            'comment' => $comment !== '' ? $comment : null,
            'acted_at' => now(),
        ]);

        $log->refresh()->load(['attachments', 'internshipProfile.student', 'logActions.supervisor']);

        $this->notifyStudentOfReview($log, $targetStatus, $request->user()->name, $comment);

        // Dispatch email notification to student
        if ($targetStatus === 'APPROVED') {
            $this->notificationMailService->sendLogApprovedEmail($log, $request->user()->name);
        } else {
            $this->notificationMailService->sendLogRejectedEmail($log, $request->user()->name, $comment);
        }

        return response()->json([
            'success' => true,
            'message' => $successMessage,
            'data' => $this->logPayloads->forReviewer($log),
        ], 200);
    }

    private function notifyStudentOfReview(
        LogEntry $log,
        string $targetStatus,
        string $supervisorName,
        ?string $comment,
    ): void {
        $studentId = $log->internshipProfile?->student_id;

        if (!$studentId) {
            return;
        }

        $isApproved = $targetStatus === 'APPROVED';
        $statusText = $isApproved ? 'approved' : 'rejected';
        $message = "Your log for {$log->date} was {$statusText} by {$supervisorName}.";

        if (!$isApproved && $comment !== null && $comment !== '') {
            $message .= " Comment: {$comment}";
        }

        Notification::create([
            'user_id' => $studentId,
            'title' => $isApproved ? 'Log approved' : 'Log rejected',
            'message' => $message,
            'is_read' => false,
        ]);
    }
}
