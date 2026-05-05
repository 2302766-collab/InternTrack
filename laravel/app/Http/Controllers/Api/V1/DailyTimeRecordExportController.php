<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\InternshipProfile;
use App\Models\User;
use App\Services\MonthlyDtrExportService;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class DailyTimeRecordExportController extends Controller
{
    public function __construct(
        private readonly MonthlyDtrExportService $exportService
    ) {
    }

    public function studentPdf(Request $request): Response
    {
        return $this->respondWithPdf(
            student: $request->user(),
            month: $this->validatedMonth($request),
            year: $this->validatedYear($request)
        );
    }

    public function studentExcel(Request $request): Response
    {
        return $this->respondWithCsv(
            student: $request->user(),
            month: $this->validatedMonth($request),
            year: $this->validatedYear($request)
        );
    }

    public function supervisorPdf(Request $request, int $id): Response
    {
        $student = $this->resolveAssignedStudent(
            studentId: $id,
            ownerColumn: 'supervisor_id',
            ownerId: $request->user()->id,
            forbiddenMessage: 'You are not allowed to access this student\'s DTR export.'
        );

        return $this->respondWithPdf(
            student: $student,
            month: $this->validatedMonth($request),
            year: $this->validatedYear($request)
        );
    }

    public function supervisorExcel(Request $request, int $id): Response
    {
        $student = $this->resolveAssignedStudent(
            studentId: $id,
            ownerColumn: 'supervisor_id',
            ownerId: $request->user()->id,
            forbiddenMessage: 'You are not allowed to access this student\'s DTR export.'
        );

        return $this->respondWithCsv(
            student: $student,
            month: $this->validatedMonth($request),
            year: $this->validatedYear($request)
        );
    }

    public function adviserPdf(Request $request, int $id): Response
    {
        $student = $this->resolveAssignedStudent(
            studentId: $id,
            ownerColumn: 'adviser_id',
            ownerId: $request->user()->id,
            forbiddenMessage: 'You are not allowed to access this student\'s DTR export.'
        );

        return $this->respondWithPdf(
            student: $student,
            month: $this->validatedMonth($request),
            year: $this->validatedYear($request)
        );
    }

    public function adviserExcel(Request $request, int $id): Response
    {
        $student = $this->resolveAssignedStudent(
            studentId: $id,
            ownerColumn: 'adviser_id',
            ownerId: $request->user()->id,
            forbiddenMessage: 'You are not allowed to access this student\'s DTR export.'
        );

        return $this->respondWithCsv(
            student: $student,
            month: $this->validatedMonth($request),
            year: $this->validatedYear($request)
        );
    }

    public function adminPdf(Request $request, int $id): Response
    {
        $student = $this->resolveStudent($id);

        return $this->respondWithPdf(
            student: $student,
            month: $this->validatedMonth($request),
            year: $this->validatedYear($request)
        );
    }

    public function adminExcel(Request $request, int $id): Response
    {
        $student = $this->resolveStudent($id);

        return $this->respondWithCsv(
            student: $student,
            month: $this->validatedMonth($request),
            year: $this->validatedYear($request)
        );
    }

    private function respondWithPdf(User $student, int $month, int $year): Response
    {
        $data = $this->exportService->buildMonthlyExportData($student, $month, $year);
        $pdf = $this->exportService->renderPdf($data);

        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="' . $this->exportService->pdfFilename($student, $month, $year) . '"',
        ]);
    }

    private function respondWithCsv(User $student, int $month, int $year): Response
    {
        $data = $this->exportService->buildMonthlyExportData($student, $month, $year);
        $csv = $this->exportService->renderCsv($data);

        return response($csv, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="' . $this->exportService->csvFilename($student, $month, $year) . '"',
        ]);
    }

    private function resolveAssignedStudent(
        int $studentId,
        string $ownerColumn,
        int $ownerId,
        string $forbiddenMessage
    ): User {
        $student = $this->resolveStudent($studentId);

        $isAssigned = InternshipProfile::query()
            ->where('student_id', $student->id)
            ->where($ownerColumn, $ownerId)
            ->exists();

        if (!$isAssigned) {
            abort(response()->json([
                'success' => false,
                'message' => $forbiddenMessage,
                'data' => null,
            ], 403));
        }

        return $student;
    }

    private function resolveStudent(int $studentId): User
    {
        $student = User::query()
            ->where('id', $studentId)
            ->whereHas('role', function ($query): void {
                $query->where('name', 'Student');
            })
            ->first();

        if ($student === null) {
            abort(response()->json([
                'success' => false,
                'message' => 'Student not found.',
                'data' => null,
            ], 404));
        }

        return $student;
    }

    private function validatedMonth(Request $request): int
    {
        return (int) $request->validate([
            'month' => ['required', 'integer', 'between:1,12'],
        ])['month'];
    }

    private function validatedYear(Request $request): int
    {
        return (int) $request->validate([
            'year' => ['required', 'integer', 'between:2000,2100'],
        ])['year'];
    }
}
