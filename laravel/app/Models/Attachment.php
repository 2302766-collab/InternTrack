<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Attachment extends Model
{
    use HasFactory;

    protected $fillable = [
        'log_entry_id',
        'file_path',
        'file_type',
        'file_size',
    ];

    public function logEntry()
    {
        return $this->belongsTo(LogEntry::class, 'log_entry_id');
    }
}
