<?php

namespace App\Http\Controllers\Api\V1\Supervisor;

use App\Http\Controllers\Controller;
use App\Models\InternshipProfile;
use App\Models\LogEntry;
use App\Services\InternshipMetricsService;
use Illuminate\Http\Request;

class SupervisorInternController extends Controller
{
    public function __construct(
        private readonly InternshipMetricsService $metricsService
    ) {
    }

    public function index(Request $request)
    {
        $validated = $request->validate([
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:10', 'max:20'],
            'search' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        $search = trim((string) ($validated['search'] ?? ''));
        $perPage = (int) ($validated['per_page'] ?? 10);

        $query = InternshipProfile::with('student')
            ->where('supervisor_id', $request->user()->id);

        if ($search !== '') {
            $query->where(function ($builder) use ($search) {
                $builder->where('company_name', 'like', "%{$search}%")
                    ->orWhereHas('student', function ($studentQuery) use ($search) {
                        $studentQuery->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%");
                    });
            });
        }

        $profiles = $query
            ->orderBy('id')
            ->paginate($perPage);

        $summaries = LogEntry::query()
            ->whereIn('internship_profile_id', $profiles->getCollection()->pluck('id'))
            ->selectRaw('internship_profile_id')
            ->selectRaw('COUNT(*) as total_logs')
            ->selectRaw("SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) as pending_logs")
            ->selectRaw("SUM(CASE WHEN status = 'APPROVED' THEN 1 ELSE 0 END) as approved_logs")
            ->selectRaw("SUM(CASE WHEN status = 'REJECTED' THEN 1 ELSE 0 END) as rejected_logs")
            ->selectRaw("SUM(CASE WHEN status = 'APPROVED' THEN hours_rendered ELSE 0 END) as completed_hours")
            ->selectRaw('MAX(date) as last_log_date')
            ->groupBy('internship_profile_id')
            ->get()
            ->keyBy('internship_profile_id');

        $formattedProfiles = $profiles->getCollection()->map(function ($profile) use ($summaries) {
            $summary = $summaries->get($profile->id);

            return [
                'id' => $profile->id,
                'student_name' => $profile->student?->name,
                'student_id' => $profile->student?->id,
                'company_name' => $profile->company_name,
                'required_hours' => $profile->required_hours,
                'supervisor_id' => $profile->supervisor_id,
                'adviser_id' => $profile->adviser_id,
                'start_date' => $profile->start_date,
                'end_date' => $profile->end_date,
                'completed_hours' => (int) ($summary?->completed_hours ?? 0),
                'total_logs' => (int) ($summary?->total_logs ?? 0),
                'pending_logs' => (int) ($summary?->pending_logs ?? 0),
                'approved_logs' => (int) ($summary?->approved_logs ?? 0),
                'rejected_logs' => (int) ($summary?->rejected_logs ?? 0),
                'last_log_date' => $summary?->last_log_date,
            ];
        })->values();

        return response()->json([
            'success' => true,
            'message' => 'Supervisor intern list retrieved successfully.',
            'data' => $formattedProfiles,
            'meta' => $this->buildPaginationMeta($profiles),
        ], 200);
    }

    public function show(Request $request, int $id)
    {
        $profile = InternshipProfile::with(['student', 'supervisor', 'adviser'])->find($id);

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Internship profile not found.',
                'data' => null,
            ], 404);
        }

        if ($profile->supervisor_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'You are not allowed to access this intern.',
                'data' => null,
            ], 403);
        }

        return response()->json([
            'success' => true,
            'message' => 'Supervisor intern retrieved successfully.',
            'data' => $this->buildInternPayload($profile),
        ], 200);
    }

    public function progress(Request $request, int $studentId)
    {
        $profile = InternshipProfile::with('student')
            ->where('student_id', $studentId)
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
                'message' => 'You are not allowed to access this student\'s progress.',
                'data' => null,
            ], 403);
        }

        return response()->json([
            'success' => true,
            'message' => 'Student progress retrieved successfully.',
            'data' => [
                'student_id' => $profile->student?->id,
                'student_name' => $profile->student?->name,
                'required_hours' => $profile->required_hours,
                'progress' => $this->buildProgressPayload($profile),
            ],
        ], 200);
    }

    private function buildInternPayload(InternshipProfile $profile): array
    {
        $progress = $this->buildProgressPayload($profile);

        $recentLogs = LogEntry::query()
            ->withCount('attachments')
            ->where('internship_profile_id', $profile->id)
            ->orderByDesc('date')
            ->orderByDesc('id')
            ->limit(5)
            ->get([
                'id',
                'internship_profile_id',
                'date',
                'hours_rendered',
                'task_description',
                'status',
                'submitted_at',
            ]);

        return [
            'id' => $profile->id,
            'student_id' => $profile->student?->id,
            'student_name' => $profile->student?->name,
            'student_email' => $profile->student?->email,
            'company_name' => $profile->company_name,
            'company_address' => $profile->company_address,
            'required_hours' => $profile->required_hours,
            'supervisor_id' => $profile->supervisor_id,
            'adviser_id' => $profile->adviser_id,
            'supervisor_name' => $profile->supervisor?->name,
            'adviser_name' => $profile->adviser?->name,
            'start_date' => $profile->start_date,
            'end_date' => $profile->end_date,
            'progress' => $progress,
            'recent_logs' => $recentLogs->map(function (LogEntry $log) {
                return [
                    'id' => $log->id,
                    'internship_profile_id' => $log->internship_profile_id,
                    'date' => $log->date,
                    'hours_rendered' => $log->hours_rendered,
                    'task_description' => $log->task_description,
                    'status' => $log->status,
                    'submitted_at' => $log->submitted_at,
                    'attachments_count' => $log->attachments_count ?? 0,
                ];
            })->values(),
        ];
    }

    private function buildProgressPayload(InternshipProfile $profile): array
    {
        return $this->metricsService->buildProgress($profile);
    }

    private function buildPaginationMeta($paginator): array
    {
        return [
            'current_page' => $paginator->currentPage(),
            'last_page' => $paginator->lastPage(),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
            'from' => $paginator->firstItem(),
            'to' => $paginator->lastItem(),
            'has_more_pages' => $paginator->hasMorePages(),
        ];
    }
}
