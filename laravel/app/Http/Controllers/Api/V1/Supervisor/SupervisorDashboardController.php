<?php

namespace App\Http\Controllers\Api\V1\Supervisor;

use App\Http\Controllers\Controller;
use App\Models\InternshipProfile;
use App\Models\LogAction;
use App\Models\LogEntry;
use App\Services\DashboardCacheService;
use Illuminate\Http\Request;

class SupervisorDashboardController extends Controller
{
    public function __construct(private readonly DashboardCacheService $dashboardCache)
    {
    }

    public function index(Request $request)
    {
        $supervisorId = $request->user()->id;

        $data = $this->dashboardCache->rememberSupervisorDashboard($supervisorId, function () use ($supervisorId) {
            $profileIds = InternshipProfile::query()
                ->where('supervisor_id', $supervisorId)
                ->pluck('id');

            $totalStudents = $profileIds->count();
            $pendingReview = 0;

            if ($profileIds->isNotEmpty()) {
                $pendingReview = LogEntry::query()
                    ->whereIn('internship_profile_id', $profileIds)
                    ->where('status', 'PENDING')
                    ->count();
            }

            $approvedToday = LogAction::query()
                ->where('supervisor_id', $supervisorId)
                ->where('action', 'APPROVED')
                ->whereDate('acted_at', now()->toDateString())
                ->count();

            return [
                'pending_review' => $pendingReview,
                'approved_today' => $approvedToday,
                'total_students' => $totalStudents,
            ];
        });

        return response()->json([
            'success' => true,
            'message' => 'Supervisor dashboard metrics retrieved successfully.',
            'data' => $data,
        ], 200);
    }
}
