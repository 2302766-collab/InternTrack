<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\InternshipProfile;
use App\Models\User;
use App\Services\MonthlyDtrExportService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Validator;

class DailyTimeRecordExportController extends Controller
{
    public function __construct(
        private readonly MonthlyDtrExportService $exportService
    ) {
    }

    public function studentPdf(Request $request): Response
    {
        $period = $this->validatedExportPeriod($request);

        return $this->respondWithPdf(
            student: $request->user(),
            period: $period
        );
    }

    public function studentExcel(Request $request): Response
    {
        $period = $this->validatedExportPeriod($request);

        return $this->respondWithCsv(
            student: $request->user(),
            period: $period
        );
    }

    public function supervisorPdf(Request $request, int $id): Response
    {
        $period = $this->validatedExportPeriod($request);
        $student = $this->resolveAssignedStudent(
            studentId: $id,
            ownerColumn: 'supervisor_id',
            ownerId: $request->user()->id,
            forbiddenMessage: 'You are not allowed to access this student\'s DTR export.'
        );

        return $this->respondWithPdf(
            student: $student,
            period: $period
        );
    }

    public function supervisorExcel(Request $request, int $id): Response
    {
        $period = $this->validatedExportPeriod($request);
        $student = $this->resolveAssignedStudent(
            studentId: $id,
            ownerColumn: 'supervisor_id',
            ownerId: $request->user()->id,
            forbiddenMessage: 'You are not allowed to access this student\'s DTR export.'
        );

        return $this->respondWithCsv(
            student: $student,
            period: $period
        );
    }

    public function adviserPdf(Request $request, int $id): Response
    {
        $period = $this->validatedExportPeriod($request);
        $student = $this->resolveAssignedStudent(
            studentId: $id,
            ownerColumn: 'adviser_id',
            ownerId: $request->user()->id,
            forbiddenMessage: 'You are not allowed to access this student\'s DTR export.'
        );

        return $this->respondWithPdf(
            student: $student,
            period: $period
        );
    }

    public function adviserExcel(Request $request, int $id): Response
    {
        $period = $this->validatedExportPeriod($request);
        $student = $this->resolveAssignedStudent(
            studentId: $id,
            ownerColumn: 'adviser_id',
            ownerId: $request->user()->id,
            forbiddenMessage: 'You are not allowed to access this student\'s DTR export.'
        );

        return $this->respondWithCsv(
            student: $student,
            period: $period
        );
    }

    public function adminPdf(Request $request, int $id): Response
    {
        $period = $this->validatedExportPeriod($request);
        $student = $this->resolveStudent($id);

        return $this->respondWithPdf(
            student: $student,
            period: $period
        );
    }

    public function adminExcel(Request $request, int $id): Response
    {
        $period = $this->validatedExportPeriod($request);
        $student = $this->resolveStudent($id);

        return $this->respondWithCsv(
            student: $student,
            period: $period
        );
    }

    private function respondWithPdf(User $student, array $period): Response
    {
        $data = $this->exportService->buildMonthlyExportData(
            $student,
            $period['month'],
            $period['year'],
            $period['start_date'],
            $period['end_date'],
        );
        $pdf = $this->exportService->renderPdf($data);

        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="' . $this->exportService->pdfFilename($student, $period['month'], $period['year']) . '"',
        ]);
    }

    private function respondWithCsv(User $student, array $period): Response
    {
        $data = $this->exportService->buildMonthlyExportData(
            $student,
            $period['month'],
            $period['year'],
            $period['start_date'],
            $period['end_date'],
        );
        $csv = $this->exportService->renderCsv($data);

        return response($csv, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="' . $this->exportService->csvFilename($student, $period['month'], $period['year']) . '"',
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

    private function validatedExportPeriod(Request $request): array
    {
        if ($request->filled('start_date') || $request->filled('end_date')) {
            $validator = Validator::make($request->all(), [
                'start_date' => ['required', 'date'],
                'end_date' => ['required', 'date', 'after_or_equal:start_date'],
            ]);

            $validator->after(function ($validator) use ($request): void {
                if ($validator->errors()->isNotEmpty()) {
                    return;
                }

                $startDate = Carbon::parse((string) $request->input('start_date'));
                $endDate = Carbon::parse((string) $request->input('end_date'));

                if ($startDate->year !== $endDate->year || $startDate->month !== $endDate->month) {
                    $validator->errors()->add(
                        'end_date',
                        'Filtered exports must stay within a single month to preserve the DTR format.',
                    );
                }
            });

            $validated = $validator->validate();
            $startDate = Carbon::parse((string) $validated['start_date'])->startOfDay();
            $endDate = Carbon::parse((string) $validated['end_date'])->startOfDay();

            return [
                'month' => $startDate->month,
                'year' => $startDate->year,
                'start_date' => $startDate->toDateString(),
                'end_date' => $endDate->toDateString(),
            ];
        }

        $validated = $request->validate([
            'month' => ['required', 'integer', 'between:1,12'],
            'year' => ['required', 'integer', 'between:2000,2100'],
        ]);

        $monthStart = Carbon::create((int) $validated['year'], (int) $validated['month'], 1)->startOfMonth();

        return [
            'month' => (int) $validated['month'],
            'year' => (int) $validated['year'],
            'start_date' => $monthStart->toDateString(),
            'end_date' => $monthStart->copy()->endOfMonth()->toDateString(),
        ];
    }
}
