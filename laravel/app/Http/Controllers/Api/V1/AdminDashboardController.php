<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;

class AdminDashboardController extends Controller
{
    public function index()
    {
        $studentRoleId = Role::query()
            ->where('name', 'Student')
            ->value('id');

        $totalStudents = 0;
        $averageCompletionPercentage = 0.0;

        if ($studentRoleId !== null) {
            $totalStudents = User::query()
                ->where('role_id', $studentRoleId)
                ->count();

            $approvedHoursPerProfile = LogEntry::query()
                ->selectRaw('internship_profile_id, SUM(CASE WHEN status = \'APPROVED\' THEN hours_rendered ELSE 0 END) as approved_hours')
                ->groupBy('internship_profile_id');

            $averageCompletionPercentage = round((float) (
                User::query()
                    ->where('users.role_id', $studentRoleId)
                    ->leftJoin('internship_profiles', 'internship_profiles.student_id', '=', 'users.id')
                    ->leftJoinSub($approvedHoursPerProfile, 'approved_log_hours', function ($join): void {
                        $join->on('approved_log_hours.internship_profile_id', '=', 'internship_profiles.id');
                    })
                    ->selectRaw('
                        AVG(
                            CASE
                                WHEN internship_profiles.required_hours IS NULL
                                    OR internship_profiles.required_hours = 0
                                THEN 0
                                ELSE (COALESCE(approved_log_hours.approved_hours, 0) * 100.0 / internship_profiles.required_hours)
                            END
                        ) as average_completion_percentage
                    ')
                    ->value('average_completion_percentage')
                ) ?? 0, 2);
        }

        $logSummary = LogEntry::query()
            ->selectRaw("SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) as pending_logs")
            ->selectRaw("SUM(CASE WHEN status = 'APPROVED' THEN 1 ELSE 0 END) as approved_logs")
            ->first();

        return response()->json([
            'success' => true,
            'message' => 'Admin dashboard metrics retrieved successfully.',
            'data' => [
                'total_students' => $totalStudents,
                'pending_logs' => (int) ($logSummary?->pending_logs ?? 0),
                'approved_logs' => (int) ($logSummary?->approved_logs ?? 0),
                'average_completion_percentage' => $averageCompletionPercentage,
            ],
        ], 200);
    }
}
