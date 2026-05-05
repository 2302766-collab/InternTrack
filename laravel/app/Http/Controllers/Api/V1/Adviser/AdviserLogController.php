<?php

namespace App\Http\Controllers\Api\V1\Adviser;

use App\Http\Controllers\Controller;
use App\Models\Attachment;
use App\Models\LogEntry;
use App\Services\AttachmentFileService;
use App\Services\LogPayloadService;
use Illuminate\Http\Request;

class AdviserLogController extends Controller
{
    public function __construct(
        private readonly LogPayloadService $logPayloads,
        private readonly AttachmentFileService $attachmentFiles,
    ) {
    }

    public function show(Request $request, int $id)
    {
        $log = LogEntry::with(['attachments', 'internshipProfile.student', 'logActions.supervisor'])
            ->find($id);

        if (!$log) {
            return response()->json([
                'success' => false,
                'message' => 'Log not found.',
                'data' => null,
            ], 404);
        }

        if (!$this->adviserCanAccessLog($request, $log)) {
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

    public function downloadAttachment(Request $request, int $id, int $attachmentId)
    {
        $log = LogEntry::with('internshipProfile')->find($id);

        if (!$log) {
            return response()->json([
                'success' => false,
                'message' => 'Log not found.',
                'data' => null,
            ], 404);
        }

        if (!$this->adviserCanAccessLog($request, $log)) {
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

    private function adviserCanAccessLog(Request $request, LogEntry $log): bool
    {
        return $log->internshipProfile?->adviser_id === $request->user()->id;
    }

}
