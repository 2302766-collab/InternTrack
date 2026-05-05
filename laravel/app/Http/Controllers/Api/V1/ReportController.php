<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\InternshipProfile;
use App\Services\InternshipMetricsService;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function __construct(
        private readonly InternshipMetricsService $metricsService
    ) {
    }

    public function student(Request $request)
    {
        $profile = InternshipProfile::with(['student', 'supervisor'])
            ->where('student_id', $request->user()->id)
            ->first();

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Internship profile is required before generating a report.',
                'data' => null,
            ], 404);
        }

        [$startDate, $endDate] = $this->validatedDateRange($request);

        return $this->reportResponse(
            profile: $profile,
            startDate: $startDate,
            endDate: $endDate,
            message: 'Student report data retrieved successfully.'
        );
    }

    public function supervisor(Request $request, int $id)
    {
        $profile = InternshipProfile::with(['student', 'supervisor'])
            ->where('student_id', $id)
            ->first();

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Student not found.',
                'data' => null,
            ], 404);
        }

        if ($profile->supervisor_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'You are not allowed to access this student report.',
                'data' => null,
            ], 403);
        }

        [$startDate, $endDate] = $this->validatedDateRange($request);

        return $this->reportResponse(
            profile: $profile,
            startDate: $startDate,
            endDate: $endDate,
            message: 'Supervisor student report data retrieved successfully.'
        );
    }

    public function adviser(Request $request, int $id)
    {
        $profile = InternshipProfile::with(['student', 'supervisor'])
            ->where('student_id', $id)
            ->first();

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Student not found.',
                'data' => null,
            ], 404);
        }

        if ($profile->adviser_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'You are not allowed to access this student report.',
                'data' => null,
            ], 403);
        }

        [$startDate, $endDate] = $this->validatedDateRange($request);

        return $this->reportResponse(
            profile: $profile,
            startDate: $startDate,
            endDate: $endDate,
            message: 'Adviser student report data retrieved successfully.'
        );
    }

    private function validatedDateRange(Request $request): array
    {
        $validated = $request->validate([
            'start_date' => ['nullable', 'date', 'before_or_equal:end_date'],
            'end_date' => ['nullable', 'date', 'after_or_equal:start_date'],
        ]);

        return [
            $validated['start_date'] ?? null,
            $validated['end_date'] ?? null,
        ];
    }

    private function reportResponse(
        InternshipProfile $profile,
        ?string $startDate,
        ?string $endDate,
        string $message
    ) {
        $logs = $this->metricsService
            ->approvedLogsQuery($profile, $startDate, $endDate)
            ->orderBy('date')
            ->orderBy('id')
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
            'message' => $message,
            'data' => [
                'student' => [
                    'id' => $profile->student?->id,
                    'name' => $profile->student?->name,
                    'email' => $profile->student?->email,
                ],
                'supervisor' => [
                    'id' => $profile->supervisor?->id,
                    'name' => $profile->supervisor?->name,
                    'email' => $profile->supervisor?->email,
                ],
                'date_range' => [
                    'start_date' => $startDate,
                    'end_date' => $endDate,
                ],
                'logs' => $logs->map(function ($log) {
                    return [
                        'id' => $log->id,
                        'internship_profile_id' => $log->internship_profile_id,
                        'date' => $log->date,
                        'hours_rendered' => $log->hours_rendered,
                        'task_description' => $log->task_description,
                        'status' => $log->status,
                        'submitted_at' => $log->submitted_at,
                    ];
                })->values(),
                'summary' => $this->metricsService->buildReportSummary(
                    profile: $profile,
                    startDate: $startDate,
                    endDate: $endDate,
                ),
            ],
        ], 200);
    }
}
