<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\InternshipProfile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class StudentAdviserController extends Controller
{
    /**
     * Assign or update adviser for a student's internship profile
     */
    public function assignAdviser(Request $request, int $studentId)
    {
        // Get the student
        $student = User::find($studentId);

        if (!$student) {
            return response()->json([
                'success' => false,
                'message' => 'Student not found.',
                'data' => null,
            ], 404);
        }

        // Get the student role to verify this is actually a student
        $studentRole = Role::where('name', 'Student')->first();
        if (!$student->role_id || $student->role_id !== $studentRole?->id) {
            return response()->json([
                'success' => false,
                'message' => 'This user is not a student.',
                'data' => null,
            ], 400);
        }

        // Get or create internship profile
        $profile = InternshipProfile::firstOrCreate(
            ['student_id' => $studentId],
            [
                'student_id' => $studentId,
                'company_name' => null,
                'company_address' => 'N/A',
                'supervisor_id' => null,
                'adviser_id' => null,
                'required_hours' => 0,
                'start_date' => now()->toDateString(),
                'end_date' => now()->addMonths(3)->toDateString(),
            ]
        );

        // Validate request
        $validated = $request->validate([
            'adviser_id' => ['nullable', 'integer', 'exists:users,id'],
        ]);

        $adviserId = $validated['adviser_id'];

        // If adviser_id provided, validate that user exists and has adviser role
        if ($adviserId !== null) {
            $adviser = User::find($adviserId);

            if (!$adviser) {
                return response()->json([
                    'success' => false,
                    'message' => 'Adviser not found.',
                    'data' => null,
                ], 404);
            }

            $adviserRole = Role::where('name', 'Adviser')->first();
            if (!$adviser->role_id || $adviser->role_id !== $adviserRole?->id) {
                return response()->json([
                    'success' => false,
                    'message' => 'Selected user is not an adviser.',
                    'data' => null,
                ], 400);
            }
        }

        // Update adviser
        $profile->update([
            'adviser_id' => $adviserId,
        ]);

        // Return updated student with adviser info
        $adviser = $profile->adviser;

        return response()->json([
            'success' => true,
            'message' => $adviserId === null
                ? 'Adviser assignment removed successfully.'
                : 'Adviser assigned successfully.',
            'data' => [
                'student_id' => $student->id,
                'student_name' => $student->name,
                'adviser_id' => $adviser?->id,
                'adviser_name' => $adviser?->name,
                'assigned_at' => now()->toIso8601String(),
            ],
        ], 200);
    }

    /**
     * Get all advisers
     */
    public function getAdvisers()
    {
        $adviserRole = Role::where('name', 'Adviser')->first();

        if (!$adviserRole) {
            return response()->json([
                'success' => true,
                'message' => 'Advisers retrieved successfully.',
                'data' => [],
            ], 200);
        }

        $advisers = User::query()
            ->where('role_id', $adviserRole->id)
            ->select('id', 'name', 'email')
            ->orderBy('name')
            ->get()
            ->map(fn ($adviser) => [
                'id' => $adviser->id,
                'name' => $adviser->name,
                'email' => $adviser->email,
            ]);

        return response()->json([
            'success' => true,
            'message' => 'Advisers retrieved successfully.',
            'data' => $advisers,
        ], 200);
    }

    /**
     * Get student's current adviser info
     */
    public function getStudentAdviser(int $studentId)
    {
        $student = User::find($studentId);

        if (!$student) {
            return response()->json([
                'success' => false,
                'message' => 'Student not found.',
                'data' => null,
            ], 404);
        }

        $profile = InternshipProfile::where('student_id', $studentId)->first();

        if (!$profile) {
            return response()->json([
                'success' => true,
                'message' => 'Student has no internship profile.',
                'data' => [
                    'student_id' => $student->id,
                    'student_name' => $student->name,
                    'adviser_id' => null,
                    'adviser_name' => null,
                ],
            ], 200);
        }

        $adviser = $profile->adviser;

        return response()->json([
            'success' => true,
            'message' => 'Student adviser info retrieved successfully.',
            'data' => [
                'student_id' => $student->id,
                'student_name' => $student->name,
                'adviser_id' => $adviser?->id,
                'adviser_name' => $adviser?->name,
            ],
        ], 200);
    }
}
