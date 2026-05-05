<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DailyTimeRecord extends Model
{
    use HasFactory;

    protected $fillable = [
        'student_id',
        'date',
        'time_in_at',
        'lunch_out_at',
        'lunch_in_at',
        'time_out_at',
        'first_work_minutes',
        'second_work_minutes',
        'total_work_minutes',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'date' => 'date',
            'time_in_at' => 'datetime',
            'lunch_out_at' => 'datetime',
            'lunch_in_at' => 'datetime',
            'time_out_at' => 'datetime',
        ];
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(User::class, 'student_id');
    }
}
