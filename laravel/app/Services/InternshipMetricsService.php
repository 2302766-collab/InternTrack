<?php

namespace App\Services;

use App\Models\InternshipProfile;
use App\Models\LogEntry;
use Illuminate\Database\Eloquent\Builder;

class InternshipMetricsService
{
    public function buildProgress(InternshipProfile $profile): array
    {
        $logSummary = LogEntry::query()
            ->where('internship_profile_id', $profile->id)
            ->selectRaw('COUNT(*) as total_logs')
            ->selectRaw("SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) as pending_logs")
            ->selectRaw("SUM(CASE WHEN status = 'APPROVED' THEN 1 ELSE 0 END) as approved_logs")
            ->selectRaw("SUM(CASE WHEN status = 'REJECTED' THEN 1 ELSE 0 END) as rejected_logs")
            ->selectRaw("SUM(CASE WHEN status = 'APPROVED' THEN hours_rendered ELSE 0 END) as completed_hours")
            ->first();

        return [
            'completed_hours' => (int) ($logSummary?->completed_hours ?? 0),
            'total_logs' => (int) ($logSummary?->total_logs ?? 0),
            'pending_logs' => (int) ($logSummary?->pending_logs ?? 0),
            'approved_logs' => (int) ($logSummary?->approved_logs ?? 0),
            'rejected_logs' => (int) ($logSummary?->rejected_logs ?? 0),
        ];
    }

    public function buildReportSummary(
        InternshipProfile $profile,
        ?string $startDate = null,
        ?string $endDate = null
    ): array {
        $approvedHours = (int) (
            $this->approvedLogsQuery($profile, $startDate, $endDate)
                ->sum('hours_rendered')
        );

        $requiredHours = (int) $profile->required_hours;
        $completionPercentage = $requiredHours > 0
            ? round(($approvedHours / $requiredHours) * 100, 2)
            : 0;

        return [
            'approved_hours' => $approvedHours,
            'total_approved_hours' => $approvedHours,
            'required_hours' => $requiredHours,
            'completion_percentage' => (float) $completionPercentage,
        ];
    }

    public function approvedLogsQuery(
        InternshipProfile $profile,
        ?string $startDate = null,
        ?string $endDate = null
    ): Builder {
        $query = LogEntry::query()
            ->where('internship_profile_id', $profile->id)
            ->where('status', 'APPROVED');

        if ($startDate) {
            $query->whereDate('date', '>=', $startDate);
        }

        if ($endDate) {
            $query->whereDate('date', '<=', $endDate);
        }

        return $query;
    }
}
