<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use App\Services\DashboardCacheService;

class AdminDashboardController extends Controller
{
    public function __construct(private readonly DashboardCacheService $dashboardCache)
    {
    }

    public function index()
    {
        $data = $this->dashboardCache->rememberAdminDashboard(function () {
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
        $totalStudents = 0;
        $averageCompletionPercentage = 0.0;
        $studentsWithoutProfile = 0;
        $studentsWithoutSupervisor = 0;
        $studentsWithoutAdviser = 0;
        $studentsRequiringAttention = 0;

        if ($studentRoleId !== null) {
            $approvedHoursPerProfile = LogEntry::query()
                ->selectRaw('internship_profile_id, SUM(CASE WHEN status = \'APPROVED\' THEN hours_rendered ELSE 0 END) as approved_hours')
                ->groupBy('internship_profile_id');

            $studentSetupSummary = User::query()
                ->where('users.role_id', $studentRoleId)
                ->leftJoin('internship_profiles', 'internship_profiles.student_id', '=', 'users.id')
                ->selectRaw('COUNT(users.id) as total_students')
                ->selectRaw('SUM(CASE WHEN internship_profiles.id IS NULL THEN 1 ELSE 0 END) as students_without_profile')
                ->selectRaw('SUM(CASE WHEN internship_profiles.id IS NOT NULL AND internship_profiles.supervisor_id IS NULL THEN 1 ELSE 0 END) as students_without_supervisor')
                ->selectRaw('SUM(CASE WHEN internship_profiles.id IS NOT NULL AND internship_profiles.adviser_id IS NULL THEN 1 ELSE 0 END) as students_without_adviser')
                ->selectRaw('SUM(CASE WHEN internship_profiles.id IS NULL OR internship_profiles.supervisor_id IS NULL OR internship_profiles.adviser_id IS NULL THEN 1 ELSE 0 END) as students_requiring_attention')
                ->first();

            $totalStudents = (int) ($studentSetupSummary?->total_students ?? 0);
            $studentsWithoutProfile = (int) ($studentSetupSummary?->students_without_profile ?? 0);
            $studentsWithoutSupervisor = (int) ($studentSetupSummary?->students_without_supervisor ?? 0);
            $studentsWithoutAdviser = (int) ($studentSetupSummary?->students_without_adviser ?? 0);
            $studentsRequiringAttention = (int) ($studentSetupSummary?->students_requiring_attention ?? 0);

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

            return [
                'total_students' => $totalStudents,
                'pending_logs' => (int) ($logSummary?->pending_logs ?? 0),
                'approved_logs' => (int) ($logSummary?->approved_logs ?? 0),
                'students_without_profile' => $studentsWithoutProfile,
                'students_without_supervisor' => $studentsWithoutSupervisor,
                'students_without_adviser' => $studentsWithoutAdviser,
                'students_requiring_attention' => $studentsRequiringAttention,
                'average_completion_percentage' => $averageCompletionPercentage,
            ];
        });

        return response()->json([
            'success' => true,
            'message' => 'Admin dashboard metrics retrieved successfully.',
            'data' => $data,
        ], 200);
    }
}
