<?php

namespace App\Services;

use App\Models\DailyTimeRecord;
use App\Models\InternshipProfile;
use App\Models\User;
use App\Support\SimplePdfDocument;
use Carbon\Carbon;
use Carbon\CarbonPeriod;

class MonthlyDtrExportService
{
    public function buildMonthlyExportData(
        User $student,
        int $month,
        int $year,
        ?string $startDate = null,
        ?string $endDate = null,
    ): array
    {
        $schedule = config('dtr.schedule');
        $monthStart = Carbon::create($year, $month, 1)->startOfMonth();
        $monthEnd = $monthStart->copy()->endOfMonth();
        $filterStart = $startDate !== null
            ? Carbon::parse($startDate)->startOfDay()
            : $monthStart->copy()->startOfDay();
        $filterEnd = $endDate !== null
            ? Carbon::parse($endDate)->startOfDay()
            : $monthEnd->copy()->startOfDay();

        $profile = InternshipProfile::query()
            ->where('student_id', $student->id)
            ->first();

        $records = DailyTimeRecord::query()
            ->where('student_id', $student->id)
            ->whereDate('date', '>=', $filterStart->toDateString())
            ->whereDate('date', '<=', $filterEnd->toDateString())
            ->orderBy('date')
            ->get()
            ->keyBy(fn (DailyTimeRecord $record) => $record->date->toDateString());

        $rows = [];
        foreach (CarbonPeriod::create($monthStart, $monthEnd) as $date) {
            /** @var Carbon $date */
            $record = $records->get($date->toDateString());
            $undertimeMinutes = $record ? $this->computeUndertimeMinutes($record) : null;

            $rows[] = [
                'day' => $date->day,
                'am_arrival' => $this->formatTime($record?->time_in_at),
                'am_departure' => $this->formatTime($record?->lunch_out_at),
                'pm_arrival' => $this->formatTime($record?->lunch_in_at),
                'pm_departure' => $this->formatTime($record?->time_out_at),
                'undertime_hours' => $undertimeMinutes === null ? '' : (string) intdiv($undertimeMinutes, 60),
                'undertime_minutes' => $undertimeMinutes === null ? '' : (string) ($undertimeMinutes % 60),
                'status' => $record?->status,
            ];
        }

        return [
            'student_name' => $student->name,
            'company_name' => $profile?->company_name,
            'month' => $monthStart->month,
            'year' => $monthStart->year,
            'month_year' => $monthStart->format('F Y'),
            'regular_days' => $schedule['regular_days'] ?? 'Monday - Friday',
            'am_schedule' => sprintf('%s - %s', $schedule['am_start'] ?? '08:00', $schedule['am_end'] ?? '12:00'),
            'pm_schedule' => sprintf('%s - %s', $schedule['pm_start'] ?? '13:00', $schedule['pm_end'] ?? '17:00'),
            'schedule_notes' => $schedule['notes'] ?? '',
            'rows' => $rows,
        ];
    }

    public function renderCsv(array $data): string
    {
        $handle = fopen('php://temp', 'r+');

        fputcsv($handle, ['Civil Service Form No. 48']);
        fputcsv($handle, ['DAILY TIME RECORD']);
        fputcsv($handle, ['Name', $data['student_name']]);
        fputcsv($handle, ['Month / Year', $data['month_year']]);
        fputcsv($handle, ['Regular Days', $data['regular_days']]);
        fputcsv($handle, ['A.M. Schedule', $data['am_schedule']]);
        fputcsv($handle, ['P.M. Schedule', $data['pm_schedule']]);
        fputcsv($handle, ['Notes', $data['schedule_notes']]);
        fputcsv($handle, []);
        fputcsv($handle, [
            'Day',
            'A.M. Arrival',
            'A.M. Departure',
            'P.M. Arrival',
            'P.M. Departure',
            'Undertime Hours',
            'Undertime Minutes',
        ]);

        foreach ($data['rows'] as $row) {
            fputcsv($handle, [
                $row['day'],
                $row['am_arrival'],
                $row['am_departure'],
                $row['pm_arrival'],
                $row['pm_departure'],
                $row['undertime_hours'],
                $row['undertime_minutes'],
            ]);
        }

        rewind($handle);
        $csv = stream_get_contents($handle) ?: '';
        fclose($handle);

        return $csv;
    }

    public function renderPdf(array $data): string
    {
        $pdf = new SimplePdfDocument();

        $pageWidth = 595.0;
        $left = 36.0;
        $tableWidth = 523.0;
        $top = 782.0;

        $pdf->text($pageWidth / 2, $top, 'Civil Service Form No. 48', 10, 'F1', 'center');
        $pdf->text($pageWidth / 2, $top - 18, 'DAILY TIME RECORD', 16, 'F2', 'center');

        $pdf->text($left, $top - 55, 'Name:', 10, 'F2');
        $pdf->text($left + 42, $top - 55, $data['student_name'], 10);
        $pdf->line($left + 40, $top - 59, $left + 250, $top - 59);

        $pdf->text($left + 280, $top - 55, 'Month / Year:', 10, 'F2');
        $pdf->text($left + 360, $top - 55, $data['month_year'], 10);
        $pdf->line($left + 356, $top - 59, $left + 500, $top - 59);

        $pdf->text($left, $top - 78, 'Regular Days: ' . $data['regular_days'], 9);
        $pdf->text($left + 220, $top - 78, 'A.M. Schedule: ' . $data['am_schedule'], 9);
        $pdf->text($left + 380, $top - 78, 'P.M. Schedule: ' . $data['pm_schedule'], 9);
        $pdf->text($left, $top - 96, 'Notes: ' . $data['schedule_notes'], 8);

        $tableTop = $top - 120;
        $headerHeight = 22.0;
        $rowHeight = 16.0;
        $columnWidths = [32, 86, 86, 86, 86, 70, 77];
        $headers = [
            'Day',
            'A.M. Arrival',
            'A.M. Departure',
            'P.M. Arrival',
            'P.M. Departure',
            'Undertime Hrs',
            'Undertime Mins',
        ];

        $tableHeight = $headerHeight + (count($data['rows']) * $rowHeight);
        $pdf->rect($left, $tableTop - $tableHeight, $tableWidth, $tableHeight);

        $x = $left;
        foreach ($columnWidths as $width) {
            $x += $width;
            $pdf->line($x, $tableTop, $x, $tableTop - $tableHeight, 0.8);
        }

        $pdf->line($left, $tableTop - $headerHeight, $left + $tableWidth, $tableTop - $headerHeight, 0.8);

        for ($i = 1; $i <= count($data['rows']); $i++) {
            $y = $tableTop - $headerHeight - ($i * $rowHeight);
            $pdf->line($left, $y, $left + $tableWidth, $y, 0.5);
        }

        $x = $left;
        foreach ($headers as $index => $header) {
            $pdf->text($x + ($columnWidths[$index] / 2), $tableTop - 14, $header, 7, 'F2', 'center');
            $x += $columnWidths[$index];
        }

        foreach ($data['rows'] as $rowIndex => $row) {
            $y = $tableTop - $headerHeight - ($rowIndex * $rowHeight) - 12;
            $cells = [
                (string) $row['day'],
                $row['am_arrival'],
                $row['am_departure'],
                $row['pm_arrival'],
                $row['pm_departure'],
                $row['undertime_hours'],
                $row['undertime_minutes'],
            ];

            $x = $left;
            foreach ($cells as $index => $cell) {
                $pdf->text($x + ($columnWidths[$index] / 2), $y, (string) $cell, 7, 'F1', 'center');
                $x += $columnWidths[$index];
            }
        }

        $pdf->text(
            $pageWidth / 2,
            72,
            'I certify on my honor that the above is a true and correct report of the hours of work performed.',
            8,
            'F1',
            'center'
        );

        return $pdf->output();
    }

    public function csvFilename(User $student, int $month, int $year): string
    {
        return sprintf(
            'dtr_%s_%04d_%02d.csv',
            $this->normalizeFileSlug($student->name),
            $year,
            $month
        );
    }

    public function pdfFilename(User $student, int $month, int $year): string
    {
        return sprintf(
            'dtr_%s_%04d_%02d.pdf',
            $this->normalizeFileSlug($student->name),
            $year,
            $month
        );
    }

    private function computeUndertimeMinutes(DailyTimeRecord $record): int
    {
        $expectedMinutes = 8 * 60;
        $actualMinutes = (int) $record->total_work_minutes;

        if ($actualMinutes === 0 && $record->first_work_minutes > 0) {
            $actualMinutes += (int) $record->first_work_minutes;
        }

        if ($actualMinutes === 0 && $record->second_work_minutes > 0) {
            $actualMinutes += (int) $record->second_work_minutes;
        }

        return max($expectedMinutes - $actualMinutes, 0);
    }

    private function formatTime(?Carbon $value): string
    {
        if ($value === null) {
            return '';
        }

        return $value->format('h:i A');
    }

    private function normalizeFileSlug(string $value): string
    {
        return trim(preg_replace('/[^A-Za-z0-9]+/', '_', strtolower($value)) ?? 'student', '_');
    }
}
