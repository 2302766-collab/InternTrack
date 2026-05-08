<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\LogEntry;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\Request;

class AdminStudentController extends Controller
{
    public function index(Request $request)
    {
        $validated = $request->validate([
            'per_page' => ['nullable', 'integer', 'between:10,20'],
        ]);

        $perPage = (int) ($validated['per_page'] ?? 10);
        $studentRoleId = Role::query()
            ->where('name', 'Student')
            ->value('id');

        if ($studentRoleId === null) {
            return response()->json([
                'success' => true,
                'message' => 'Admin students retrieved successfully.',
                'data' => [],
                'meta' => [
                    'current_page' => 1,
                    'per_page' => $perPage,
                    'total' => 0,
                    'last_page' => 1,
                    'has_more_pages' => false,
                ],
            ], 200);
        }

        $approvedHoursPerProfile = LogEntry::query()
            ->selectRaw('internship_profile_id, SUM(CASE WHEN status = \'APPROVED\' THEN hours_rendered ELSE 0 END) as approved_hours')
            ->groupBy('internship_profile_id');

        $students = User::query()
            ->where('users.role_id', $studentRoleId)
            ->leftJoin('internship_profiles', 'internship_profiles.student_id', '=', 'users.id')
            ->leftJoinSub($approvedHoursPerProfile, 'approved_log_hours', function ($join): void {
                $join->on('approved_log_hours.internship_profile_id', '=', 'internship_profiles.id');
            })
            ->select([
                'users.id as student_id',
                'users.name',
                'internship_profiles.company_name as company',
            ])
            ->selectRaw('CASE WHEN internship_profiles.id IS NULL THEN false ELSE true END as has_internship_profile')
            ->selectRaw('CASE WHEN internship_profiles.supervisor_id IS NULL THEN false ELSE true END as has_supervisor')
            ->selectRaw('CASE WHEN internship_profiles.adviser_id IS NULL THEN false ELSE true END as has_adviser')
            ->selectRaw('COALESCE(approved_log_hours.approved_hours, 0) as approved_hours')
            ->selectRaw('COALESCE(internship_profiles.required_hours, 0) as required_hours')
            ->selectRaw('
                CASE
                    WHEN internship_profiles.required_hours IS NULL
                        OR internship_profiles.required_hours = 0
                    THEN 0
                    ELSE ROUND((COALESCE(approved_log_hours.approved_hours, 0) * 100.0 / internship_profiles.required_hours), 2)
                END as completion_percentage
            ')
            ->orderBy('users.id')
            ->paginate($perPage);

        return response()->json([
            'success' => true,
            'message' => 'Admin students retrieved successfully.',
            'data' => collect($students->items())->map(function ($student) {
                return [
                    'student_id' => (int) $student->student_id,
                    'name' => $student->name,
                    'company' => $student->company,
                    'approved_hours' => (int) $student->approved_hours,
                    'required_hours' => (int) $student->required_hours,
                    'completion_percentage' => (float) $student->completion_percentage,
                    'has_internship_profile' => (bool) $student->has_internship_profile,
                    'has_supervisor' => (bool) $student->has_supervisor,
                    'has_adviser' => (bool) $student->has_adviser,
                ];
            })->values(),
            'meta' => [
                'current_page' => $students->currentPage(),
                'per_page' => $students->perPage(),
                'total' => $students->total(),
                'last_page' => $students->lastPage(),
                'has_more_pages' => $students->hasMorePages(),
            ],
        ], 200);
    }
}
