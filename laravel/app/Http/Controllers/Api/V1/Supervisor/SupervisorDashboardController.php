<?php

namespace App\Http\Controllers\Api\V1\Supervisor;

use App\Http\Controllers\Controller;
use App\Models\InternshipProfile;
use App\Models\LogAction;
use App\Models\LogEntry;
use Illuminate\Http\Request;

class SupervisorDashboardController extends Controller
{
    public function index(Request $request)
    {
        $supervisorId = $request->user()->id;

        $profileIds = InternshipProfile::query()
            ->where('supervisor_id', $supervisorId)
            ->pluck('id');

        $totalStudents = $profileIds->count();

        $pendingReview = 0;
        $approvedToday = 0;

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

        return response()->json([
            'success' => true,
            'message' => 'Supervisor dashboard metrics retrieved successfully.',
            'data' => [
                'pending_review' => $pendingReview,
                'approved_today' => $approvedToday,
                'total_students' => $totalStudents,
            ],
        ], 200);
    }
}
