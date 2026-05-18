<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EditRequest extends Model
{
    use HasFactory;

    public const RESOURCE_LOG = 'LOG';
    public const RESOURCE_DTR = 'DTR';
    public const STATUS_PENDING = 'PENDING';
    public const STATUS_APPROVED = 'APPROVED';
    public const STATUS_REJECTED = 'REJECTED';

    protected $fillable = [
        'requester_id',
        'reviewer_id',
        'resource_type',
        'log_entry_id',
        'daily_time_record_id',
        'status',
        'reason',
        'requested_changes',
        'review_comment',
        'reviewed_at',
    ];

    protected function casts(): array
    {
        return [
            'requested_changes' => 'array',
            'reviewed_at' => 'datetime',
        ];
    }

    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewer_id');
    }

    public function logEntry(): BelongsTo
    {
        return $this->belongsTo(LogEntry::class);
    }

    public function dailyTimeRecord(): BelongsTo
    {
        return $this->belongsTo(DailyTimeRecord::class);
    }
}
