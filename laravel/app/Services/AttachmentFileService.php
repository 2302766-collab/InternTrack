<?php

namespace App\Services;

use App\Models\Attachment;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class AttachmentFileService
{
    public function exists(Attachment $attachment): bool
    {
        return Storage::disk('local')->exists($attachment->file_path);
    }

    public function inlineResponse(Attachment $attachment): BinaryFileResponse
    {
        $path = Storage::disk('local')->path($attachment->file_path);
        $filename = basename($attachment->file_path);

        return response()->file($path, [
            'Content-Type' => $this->mimeTypeFor($attachment->file_type),
            'Content-Disposition' => 'inline; filename="' . $filename . '"',
        ]);
    }

    private function mimeTypeFor(string $fileType): string
    {
        return match (strtolower($fileType)) {
            'jpg', 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'pdf' => 'application/pdf',
            default => 'application/octet-stream',
        };
    }
}
