<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class InternshipProfile extends Model
{
    use HasFactory;

    // OPTIONAL but recommended so create() works easily
    protected $fillable = [
        'student_id',
        'company_name',
        'company_address',
        'supervisor_id',
        'adviser_id',
        'required_hours',
        'start_date',
        'end_date',
    ];

    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    public function supervisor()
    {
        return $this->belongsTo(User::class, 'supervisor_id');
    }

    public function adviser()
    {
        return $this->belongsTo(User::class, 'adviser_id');
    }
}
