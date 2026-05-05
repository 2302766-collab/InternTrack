<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Http\Controllers\Controller;
use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Services\AttachmentFileService;
use App\Services\LogPayloadService;
use App\Services\NotificationMailService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use App\Models\Attachment;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;


class LogController extends Controller
{
    private const MAX_BACKDATE_DAYS = 1; // allow today or yesterday only
    private const EDIT_WINDOW_HOURS = 24; // allow edits within 24h while pending

    public function __construct(
        private readonly LogPayloadService $logPayloads,
        private readonly AttachmentFileService $attachmentFiles,
        private readonly NotificationMailService $notificationMailService,
    ) {
    }

    private function minimumAllowedLogDate(): string
    {
        return Carbon::today()
            ->subDays(self::MAX_BACKDATE_DAYS)
            ->toDateString();
    }

    private function logDateValidationRules(): array
    {
        return [
            'required',
            'date',
            'before_or_equal:today',
            'after_or_equal:' . $this->minimumAllowedLogDate(),
        ];
    }

    private function logValidationMessages(): array
    {
        return [
            'date.before_or_equal' => 'Log date cannot be in the future.',
            'date.after_or_equal' => 'Log date must be today or yesterday.',
            'hours_rendered.min' => 'Hours must be between 1 and 12.',
            'hours_rendered.max' => 'Hours must be between 1 and 12.',
            'hours_rendered.integer' => 'Hours must be between 1 and 12.',
            'task_description.required' => 'Task description is required.',
        ];
    }

    public function store(Request $request)
    {
        $student = $request->user();

        $profile = InternshipProfile::where('student_id', $student->id)->first();

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Internship profile is required before submitting logs.',
                'data' => null,
            ], 404);
        }

        $validated = $request->validate([
            'date' => $this->logDateValidationRules(),
            'hours_rendered' => ['required', 'integer', 'min:1', 'max:12'],
            'task_description' => ['required', 'string'],
        ], $this->logValidationMessages());

        $workDate = Carbon::parse($validated['date'])->toDateString();

        $log = LogEntry::create([
            'internship_profile_id' => $profile->id,
            'date' => $workDate,
            'hours_rendered' => $validated['hours_rendered'],
            'task_description' => $validated['task_description'],
            'status' => 'PENDING',
            'submitted_at' => now(),
        ]);

        // Notify supervisor that a new log has been submitted for review
        $profile->load('supervisor');
        if ($profile->supervisor) {
            $this->notificationMailService->sendLogPendingApprovalEmail($log, $profile->supervisor);
        }

        return response()->json([
            'success' => true,
            'message' => 'Log submitted successfully.',
            'data' => $log,
        ], 201);
    }

    public function index(Request $request)
    {
        $student = $request->user();

        $profile = InternshipProfile::where('student_id', $student->id)->first();

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'No internship profile found for this student.',
                'data' => [],
            ], 404);
        }

        $logs = LogEntry::query()
            ->withCount('attachments')
            ->where('internship_profile_id', $profile->id)
            ->orderByDesc('date')
            ->orderByDesc('id')
            ->get([
                'id',
                'internship_profile_id',
                'date',
                'hours_rendered',
                'task_description',
                'status',
                'submitted_at',
            ]);

        return response()->json([
            'success' => true,
            'message' => 'Logs retrieved successfully.',
            'data' => $logs->map(function ($log) {
                return [
                    'id' => $log->id,
                    'date' => $log->date,
                    'hours_rendered' => $log->hours_rendered,
                    'task_description' => $log->task_description,
                    'status' => $log->status,
                    'submitted_at' => $log->submitted_at,
                    'attachments_count' => $log->attachments_count ?? 0,
                    'has_attachments' => ($log->attachments_count ?? 0) > 0,
                ];
            })->values(),
        ], 200);
    }

    public function show(Request $request, $id)
{
    $student = $request->user();

    $profile = InternshipProfile::where('student_id', $student->id)->first();

    if (!$profile) {
        return response()->json([
            'success' => false,
            'message' => 'Internship profile is required before accessing logs.',
            'data' => null,
        ], 404);
    }

    $log = LogEntry::with(['attachments', 'logActions.supervisor'])->find($id);

    if (!$log) {
        return response()->json([
            'success' => false,
            'message' => 'Log not found.',
            'data' => null,
        ], 404);
    }

    if ($log->internship_profile_id !== $profile->id) {
        return response()->json([
            'success' => false,
            'message' => 'You are not allowed to access this log.',
            'data' => null,
        ], 403);
    }

    return response()->json([
        'success' => true,
        'message' => 'Log retrieved successfully.',
        'data' => $this->logPayloads->forStudent($log),
    ], 200);
}
    public function update(Request $request, $id)
{
    $student = $request->user();

    $profile = InternshipProfile::where('student_id', $student->id)->first();

    if (!$profile) {
        return response()->json([
            'success' => false,
            'message' => 'Internship profile is required before updating logs.',
            'data' => null,
        ], 404);
    }

    $log = LogEntry::find($id);

    if (!$log) {
        return response()->json([
            'success' => false,
            'message' => 'Log not found.',
            'data' => null,
        ], 404);
    }

    // Ownership check
    if ($log->internship_profile_id !== $profile->id) {
        return response()->json([
            'success' => false,
            'message' => 'You are not allowed to update this log.',
            'data' => null,
        ], 403);
    }

    // Status check
    if ($log->status !== 'PENDING') {
        return response()->json([
            'success' => false,
            'message' => 'Only PENDING logs can be edited.',
            'data' => null,
        ], 403);
    }

    if ($log->created_at && $log->created_at->lt(now()->subHours(self::EDIT_WINDOW_HOURS))) {
        return response()->json([
            'success' => false,
            'message' => 'Edit window expired. Logs can be edited within 24 hours of submission while pending.',
            'data' => null,
        ], 409);
    }

    // Validation
    $validated = $request->validate([
        'date' => $this->logDateValidationRules(),
        'hours_rendered' => ['required','integer','min:1','max:12'],
        'task_description' => ['required','string'],
    ], $this->logValidationMessages());

    $workDate = Carbon::parse($validated['date'])->toDateString();

    $log->update([
        'date' => $workDate,
        'hours_rendered' => $validated['hours_rendered'],
        'task_description' => $validated['task_description'],
    ]);

    return response()->json([
        'success' => true,
        'message' => 'Log updated successfully.',
        'data' => $log
    ], 200);
}

public function uploadAttachment(Request $request, $id)
{

    $student = $request->user();

    $log = LogEntry::find($id);

    if (!$log) {
        return response()->json([
            'success' => false,
            'message' => 'Log not found.',
            'data' => null,
        ], 404);
    }

    $profile = InternshipProfile::where('student_id', $student->id)->first();

    if (!$profile || $log->internship_profile_id !== $profile->id) {
        return response()->json([
            'success' => false,
            'message' => 'You are not allowed to upload attachment to this log.',
            'data' => null,
        ], 403);
    }

    if ($log->status !== 'PENDING') {
        return response()->json([
            'success' => false,
            'message' => 'Attachments can only be added to PENDING logs.',
            'data' => null,
        ], 409);
    }

    $hasExistingAttachment = Attachment::where('log_entry_id', $log->id)->exists();

    if ($hasExistingAttachment) {
        return response()->json([
            'success' => false,
            'message' => 'A proof attachment already exists for this log.',
            'data' => null,
        ], 409);
    }

    $validator = Validator::make($request->all(), [
        // Allow common JPEG extension in addition to JPG to match client picker
        'file' => ['required', 'file', 'mimes:jpg,jpeg,png,pdf', 'extensions:jpg,jpeg,png,pdf', 'max:5120'],
    ], [
        'file.file' => 'Invalid upload payload. Use multipart/form-data and send the file in the "file" field.',
        'file.mimes' => 'Invalid file type. Only jpg, jpeg, png, and pdf are allowed.',
        'file.extensions' => 'Invalid file type. Only jpg, jpeg, png, and pdf are allowed.',
        'file.max' => 'File too large. Maximum size is 5MB.',
        'file.required' => 'File is required.',
    ]);

    if ($validator->fails()) {
        $errors = $validator->errors()->toArray();
        $fileErrors = $errors['file'] ?? [];

        $message = 'Validation failed.';
        if (in_array('Invalid file type. Only jpg, png, and pdf are allowed.', $fileErrors, true)) {
            $message = 'Invalid file type. Only jpg, png, and pdf are allowed.';
        } elseif (in_array('File too large. Maximum size is 5MB.', $fileErrors, true)) {
            $message = 'File too large. Maximum size is 5MB.';
        }

        return response()->json([
            'success' => false,
            'message' => $message,
            'data' => [
                'errors' => $errors,
            ],
        ], 422);
    }

    $file = $validator->validated()['file'];

    $extension = strtolower($file->extension());
    $uniqueFilename = now()->timestamp . '_' . Str::random(10) . '.' . $extension;

    $directory = "log_attachments/{$student->id}/{$log->id}";
    $filePath = Storage::disk('local')->putFileAs($directory, $file, $uniqueFilename);

    if ($filePath === false) {
        return response()->json([
            'success' => false,
            'message' => 'Failed to store uploaded file.',
            'data' => null,
        ], 500);
    }

    try {
        DB::beginTransaction();

        $attachment = Attachment::create([
            'log_entry_id' => $log->id,
            'file_path' => $filePath,
            'file_type' => $extension,
            'file_size' => $file->getSize(),
        ]);

        DB::commit();
    } catch (\Throwable $exception) {
        DB::rollBack();
        Storage::disk('local')->delete($filePath);

        // Log the exception for debugging
        \Illuminate\Support\Facades\Log::error('Attachment creation failed', [
            'log_id' => $log->id,
            'user_id' => $student->id,
            'error' => $exception->getMessage(),
        ]);

        // Return safe error response without exposing database internals
        return response()->json([
            'success' => false,
            'message' => 'Failed to save attachment. Please try again.',
            'data' => null,
        ], 500);
    }

    return response()->json([
        'success' => true,
        'message' => 'Attachment uploaded successfully.',
        'data' => [
            'id' => $attachment->id,
            'file_path' => $attachment->file_path,
            'file_type' => $attachment->file_type,
            'file_size' => $attachment->file_size,
            'created_at' => $attachment->created_at,
        ],
    ], 201);
}

public function downloadAttachment(Request $request, int $logId, int $attachmentId)
{
    $student = $request->user();

    $profile = InternshipProfile::where('student_id', $student->id)->first();

    if (!$profile) {
        return response()->json([
            'success' => false,
            'message' => 'Internship profile is required before accessing attachments.',
            'data' => null,
        ], 404);
    }

    $log = LogEntry::find($logId);

    if (!$log) {
        return response()->json([
            'success' => false,
            'message' => 'Log not found.',
            'data' => null,
        ], 404);
    }

    if ($log->internship_profile_id !== $profile->id) {
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
}
