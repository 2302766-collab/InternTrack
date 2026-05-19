<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Http\Controllers\Controller;
use App\Models\DailyTimeRecord;
use App\Services\MonthlyDtrExportService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DailyTimeRecordController extends Controller
{
    public function __construct(
        private readonly MonthlyDtrExportService $exportService
    ) {
    }

    public function today(Request $request): JsonResponse
    {
        $record = $this->todayRecord($request);

        return response()->json([
            'success' => true,
            'message' => 'Daily time record retrieved successfully.',
            'data' => $record
                ? $this->serializeRecord($record)
                : $this->emptyRecordPayload(),
        ], 200);
    }

    public function monthly(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'month' => ['required', 'integer', 'between:1,12'],
            'year' => ['required', 'integer', 'between:2000,2100'],
        ]);

        $data = $this->exportService->buildMonthlyExportData(
            $request->user(),
            (int) $validated['month'],
            (int) $validated['year'],
        );

        return response()->json([
            'success' => true,
            'message' => 'Monthly daily time record retrieved successfully.',
            'data' => [
                'month' => $data['month'],
                'year' => $data['year'],
                'month_year' => $data['month_year'],
                'student_name' => $data['student_name'],
                'company_name' => $data['company_name'],
                'schedule' => [
                    'regular_days' => $data['regular_days'],
                    'am_schedule' => $data['am_schedule'],
                    'pm_schedule' => $data['pm_schedule'],
                    'notes' => $data['schedule_notes'],
                ],
                'rows' => $data['rows'],
            ],
        ]);
    }

    public function timeIn(Request $request): JsonResponse
    {
        $record = $this->todayRecord($request);

        if ($record !== null && $record->time_in_at !== null) {
            return $this->conflict('Time In has already been recorded for today.');
        }

        $now = now();

        $record = DailyTimeRecord::updateOrCreate(
            [
                'student_id' => $request->user()->id,
                'date' => $now->toDateString(),
            ],
            [
                'time_in_at' => $now,
                'status' => 'WORKING',
            ],
        );

        return $this->dtrSuccessResponse(
            record: $record->fresh(),
            message: 'Time In recorded successfully.',
            status: 201,
        );
    }

    public function lunchOut(Request $request): JsonResponse
    {
        $record = $this->todayRecord($request);

        if ($record === null || $record->time_in_at === null) {
            return $this->conflict('Time In must be recorded before Lunch Out.');
        }

        if ($record->lunch_out_at !== null) {
            return $this->conflict('Lunch Out has already been recorded for today.');
        }

        if ($record->lunch_in_at !== null || $record->time_out_at !== null) {
            return $this->conflict('Lunch Out is no longer available for this record.');
        }

        $now = now();
        $firstSegmentMinutes = max(0, $record->time_in_at->diffInMinutes($now));

        $record->update([
            'lunch_out_at' => $now,
            'first_work_minutes' => $firstSegmentMinutes,
            'total_work_minutes' => $firstSegmentMinutes,
            'status' => 'ON_BREAK',
        ]);

        return $this->dtrSuccessResponse(
            record: $record->fresh(),
            message: 'Lunch Out recorded successfully.',
        );
    }

    public function lunchIn(Request $request): JsonResponse
    {
        $record = $this->todayRecord($request);

        if ($record === null || $record->lunch_out_at === null) {
            return $this->conflict('Lunch Out must be recorded before Lunch In.');
        }

        if ($record->lunch_in_at !== null) {
            return $this->conflict('Lunch In has already been recorded for today.');
        }

        if ($record->time_out_at !== null) {
            return $this->conflict('Lunch In is no longer available for this record.');
        }

        $record->update([
            'lunch_in_at' => now(),
            'status' => 'WORKING',
        ]);

        return $this->dtrSuccessResponse(
            record: $record->fresh(),
            message: 'Lunch In recorded successfully.',
        );
    }

    public function timeOut(Request $request): JsonResponse
    {
        $record = $this->todayRecord($request);

        if ($record === null || $record->lunch_in_at === null) {
            return $this->conflict('Lunch In must be recorded before Time Out.');
        }

        if ($record->time_out_at !== null) {
            return $this->conflict('Time Out has already been recorded for today.');
        }

        $now = now();
        $secondSegmentMinutes = max(0, $record->lunch_in_at->diffInMinutes($now));
        $totalMinutes = (int) $record->first_work_minutes + $secondSegmentMinutes;

        $record->update([
            'time_out_at' => $now,
            'second_work_minutes' => $secondSegmentMinutes,
            'total_work_minutes' => $totalMinutes,
            'status' => 'COMPLETED',
        ]);

        return $this->dtrSuccessResponse(
            record: $record->fresh(),
            message: 'Time Out recorded successfully.',
        );
    }

    private function todayRecord(Request $request): ?DailyTimeRecord
    {
        return DailyTimeRecord::query()
            ->where('student_id', $request->user()->id)
            ->whereDate('date', now()->toDateString())
            ->first();
    }

    private function emptyRecordPayload(): array
    {
        return [
            'date' => Carbon::today()->toDateString(),
            'status' => 'NOT_STARTED',
            'current_state_label' => 'Not Started',
            'next_action' => 'TIME_IN',
            'time_in_at' => null,
            'lunch_out_at' => null,
            'lunch_in_at' => null,
            'time_out_at' => null,
            'first_work_minutes' => 0,
            'second_work_minutes' => 0,
            'total_work_minutes' => 0,
        ];
    }

    private function serializeRecord(DailyTimeRecord $record): array
    {
        return [
            'id' => $record->id,
            'date' => $record->date?->toDateString() ?? $record->date,
            'status' => $record->status,
            'current_state_label' => $this->stateLabel($record->status),
            'next_action' => $this->nextAction($record),
            'time_in_at' => $record->time_in_at?->toIso8601String(),
            'lunch_out_at' => $record->lunch_out_at?->toIso8601String(),
            'lunch_in_at' => $record->lunch_in_at?->toIso8601String(),
            'time_out_at' => $record->time_out_at?->toIso8601String(),
            'first_work_minutes' => (int) $record->first_work_minutes,
            'second_work_minutes' => (int) $record->second_work_minutes,
            'total_work_minutes' => (int) $record->total_work_minutes,
        ];
    }

    private function nextAction(DailyTimeRecord $record): ?string
    {
        if ($record->time_in_at === null) {
            return 'TIME_IN';
        }

        if ($record->lunch_out_at === null) {
            return 'LUNCH_OUT';
        }

        if ($record->lunch_in_at === null) {
            return 'LUNCH_IN';
        }

        if ($record->time_out_at === null) {
            return 'TIME_OUT';
        }

        return null;
    }

    private function stateLabel(string $status): string
    {
        return match ($status) {
            'WORKING' => 'Working',
            'ON_BREAK' => 'On Break',
            'COMPLETED' => 'Completed',
            default => 'Not Started',
        };
    }

    private function conflict(string $message): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => $message,
            'data' => null,
        ], 409);
    }

    private function dtrSuccessResponse(
        DailyTimeRecord $record,
        string $message,
        int $status = 200
    ): JsonResponse {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $this->serializeRecord($record),
        ], $status);
    }
}
