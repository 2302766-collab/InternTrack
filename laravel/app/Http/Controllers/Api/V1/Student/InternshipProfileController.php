<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Http\Controllers\Controller;
use App\Models\InternshipProfile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class InternshipProfileController extends Controller
{
    public function supervisors()
    {
        $supervisorRoleId = Role::query()
            ->where('name', 'Supervisor')
            ->value('id');

        $supervisors = User::query()
            ->where('role_id', $supervisorRoleId)
            ->orderBy('name')
            ->get(['id', 'name', 'email'])
            ->map(function (User $user) {
                return [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role' => 'Supervisor',
                ];
            })->values();

        return response()->json([
            'success' => true,
            'message' => 'Supervisors retrieved successfully.',
            'data' => $supervisors,
        ], 200);
    }

    public function store(Request $request)
    {
        $userId = $request->user()->id;

        $supervisorRoleId = Role::query()
            ->where('name', 'Supervisor')
            ->value('id');

        if (InternshipProfile::where('student_id', $userId)->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'Internship profile already exists.',
                'data' => null,
            ], 409);
        }

        $validated = $request->validate([
            'company_name' => ['required', 'string', 'max:255'],
            'company_address' => ['required', 'string', 'max:255'],
            'supervisor_id' => [
                'required',
                'integer',
                Rule::exists('users', 'id')->where(function ($query) use ($supervisorRoleId) {
                    $query->where('role_id', $supervisorRoleId);
                }),
            ],
            'required_hours' => ['required', 'integer', 'min:1'],
            'start_date' => ['required', 'date'],
            'end_date' => ['required', 'date', 'after:start_date'],
        ]);

        $profile = InternshipProfile::create([
            'student_id' => $userId,
            'company_name' => $validated['company_name'],
            'company_address' => $validated['company_address'],
            'supervisor_id' => $validated['supervisor_id'],
            'required_hours' => $validated['required_hours'],
            'start_date' => $validated['start_date'],
            'end_date' => $validated['end_date'],
        ]);
        $profile->load('supervisor');

        return response()->json([
            'success' => true,
            'message' => 'Internship profile created successfully.',
            'data' => [
                'id' => $profile->id,
                'student_id' => $profile->student_id,
                'company_name' => $profile->company_name,
                'company_address' => $profile->company_address,
                'required_hours' => $profile->required_hours,
                'start_date' => $profile->start_date,
                'end_date' => $profile->end_date,
                'supervisor_id' => $profile->supervisor_id,
                'adviser_id' => $profile->adviser_id,
                'supervisor_name' => $profile->supervisor?->name,
                'supervisor_email' => $profile->supervisor?->email,
            ],
        ], 201);
    }


    public function show(Request $request)
    {
        $profile = InternshipProfile::with('supervisor')
            ->where('student_id', $request->user()->id)
            ->first();

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Internship profile not found.',
                'data' => null,
            ], 404);
        }
        return response()->json([
            'success' => true,
            'message' => 'Internship profile retrieved successfully.',
            'data' => [
                'id' => $profile->id,
                'student_id' => $profile->student_id,
                'company_name' => $profile->company_name,
                'company_address' => $profile->company_address,
                'required_hours' => $profile->required_hours,
                'start_date' => $profile->start_date,
                'end_date' => $profile->end_date,
                'supervisor_id' => $profile->supervisor_id,
                'adviser_id' => $profile->adviser_id,
                'supervisor_name' => $profile->supervisor?->name,
                'supervisor_email' => $profile->supervisor?->email,
            ],
        ], 200);
    }
}
