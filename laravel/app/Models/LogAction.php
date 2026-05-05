<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LogAction extends Model
{
    use HasFactory;

    protected $fillable = [
        'log_entry_id',
        'supervisor_id',
        'action',
        'comment',
        'acted_at',
    ];

    public function logEntry()
    {
        return $this->belongsTo(LogEntry::class);
    }

    public function supervisor()
    {
        return $this->belongsTo(User::class, 'supervisor_id');
    }
}
