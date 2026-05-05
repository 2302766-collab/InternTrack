<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class LogEntry extends Model
{
    use HasFactory;

    protected $fillable = [
        'internship_profile_id',
        'date',
        'hours_rendered',
        'task_description',
        'status',
        'submitted_at',
    ];

    public function internshipProfile(): BelongsTo
    {
        return $this->belongsTo(InternshipProfile::class);
    }

    public function attachments(): HasMany
    {
        return $this->hasMany(Attachment::class, 'log_entry_id');
    }

    public function logActions(): HasMany
    {
        return $this->hasMany(LogAction::class)
            ->orderByDesc('acted_at')
            ->orderByDesc('id');
    }
}
