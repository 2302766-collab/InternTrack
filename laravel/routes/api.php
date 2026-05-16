<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\Student\InternshipProfileController;
use App\Http\Controllers\Api\V1\Student\DailyTimeRecordController;
use App\Http\Controllers\Api\V1\AdminStudentController;
use App\Http\Controllers\Api\V1\Admin\StudentAdviserController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\AdminDashboardController;
use App\Http\Controllers\Api\V1\DailyTimeRecordExportController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\Admin\UserManagementController;
use App\Http\Controllers\Api\V1\Supervisor\SupervisorDashboardController;
use App\Http\Controllers\Api\V1\Supervisor\SupervisorInternController;
use App\Http\Controllers\Api\V1\Supervisor\SupervisorLogController;
use App\Http\Controllers\Api\V1\Adviser\AdviserInternController;
use App\Http\Controllers\Api\V1\Adviser\AdviserLogController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\Student\LogController;

Route::prefix('v1')->group(function () {

    // Auth routes
    Route::prefix('auth')->group(function () {
        Route::post('/register', [AuthController::class, 'register'])
            ->middleware('throttle:10,1');
        Route::post('/login', [AuthController::class, 'login'])
            ->middleware('throttle:10,1');

        Route::middleware('auth:sanctum')->group(function () {
            Route::post('/logout', [AuthController::class, 'logout']);
            Route::get('/me', [AuthController::class, 'me']);
        });
    });

    // Health endpoint
    Route::get('/health', function () {
        return response()->json([
            'success' => true,
            'message' => 'API is running',
            'timestamp' => now()->toDateTimeString(),
        ], 200);
    });

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::patch('/notifications/{id}/read', [NotificationController::class, 'markAsRead']);
        Route::get('/admin/dashboard', [AdminDashboardController::class, 'index'])
            ->middleware('role:Admin,Only admins can access dashboard metrics.');
        Route::get('/admin/students', [AdminStudentController::class, 'index'])
            ->middleware('role:Admin,Only admins can access students list.');
    });

    // Student routes
    Route::prefix('student')
        ->middleware(['auth:sanctum', 'role:Student'])
        ->group(function () {
            Route::post('/internship', [InternshipProfileController::class, 'store']);
            Route::patch('/internship', [InternshipProfileController::class, 'update']);
            Route::get('/supervisors', [InternshipProfileController::class, 'supervisors']);
            Route::get('/internship', [InternshipProfileController::class, 'show'])
                ->middleware('role:Student');
            Route::get('/report', [ReportController::class, 'student']);
            Route::get('/dtr/today', [DailyTimeRecordController::class, 'today']);
            Route::post('/dtr/time-in', [DailyTimeRecordController::class, 'timeIn']);
            Route::post('/dtr/lunch-out', [DailyTimeRecordController::class, 'lunchOut']);
            Route::post('/dtr/lunch-in', [DailyTimeRecordController::class, 'lunchIn']);
            Route::post('/dtr/time-out', [DailyTimeRecordController::class, 'timeOut']);
            Route::get('/dtr/export/pdf', [DailyTimeRecordExportController::class, 'studentPdf']);
            Route::get('/dtr/export/excel', [DailyTimeRecordExportController::class, 'studentExcel']);
        });

    // Supervisor routes
    Route::prefix('supervisor')->middleware('auth:sanctum')->group(function () {
        Route::get('/dashboard', [SupervisorDashboardController::class, 'index'])
            ->middleware('role:Supervisor');
        Route::get('/interns', [SupervisorInternController::class, 'index'])
            ->middleware('role:Supervisor');
        Route::get('/interns/{id}', [SupervisorInternController::class, 'show'])
            ->middleware('role:Supervisor');
        Route::get('/interns/{student_id}/progress', [SupervisorInternController::class, 'progress'])
            ->middleware('role:Supervisor');
        Route::get('/students/{id}/report', [ReportController::class, 'supervisor'])
            ->middleware('role:Supervisor');
        Route::get('/logs', [SupervisorLogController::class, 'index'])
            ->middleware('role:Supervisor');
        Route::get('/logs/{id}', [SupervisorLogController::class, 'show'])
            ->middleware('role:Supervisor');
        Route::get('/logs/{id}/attachments/{attachmentId}', [SupervisorLogController::class, 'downloadAttachment'])
            ->middleware('role:Supervisor');
        Route::match(['post', 'patch'], '/logs/{id}/approve', [SupervisorLogController::class, 'approve'])
            ->middleware('role:Supervisor,Only supervisors can approve logs.');
        Route::match(['post', 'patch'], '/logs/{id}/reject', [SupervisorLogController::class, 'reject'])
            ->middleware('role:Supervisor,Only supervisors can reject logs.');
        Route::get('/students/{id}/dtr/export/pdf', [DailyTimeRecordExportController::class, 'supervisorPdf'])
            ->middleware('role:Supervisor');
        Route::get('/students/{id}/dtr/export/excel', [DailyTimeRecordExportController::class, 'supervisorExcel'])
            ->middleware('role:Supervisor');
    });

    // Adviser routes
    Route::prefix('adviser')->middleware(['auth:sanctum', 'role:Adviser'])->group(function () {
        Route::get('/interns', [AdviserInternController::class, 'index']);
        Route::get('/interns/{id}', [AdviserInternController::class, 'show']);
        Route::get('/logs/{id}', [AdviserLogController::class, 'show']);
        Route::get('/logs/{id}/attachments/{attachmentId}', [AdviserLogController::class, 'downloadAttachment']);
        Route::get('/students/{id}/report', [ReportController::class, 'adviser']);
        Route::get('/students/{id}/dtr/export/pdf', [DailyTimeRecordExportController::class, 'adviserPdf']);
        Route::get('/students/{id}/dtr/export/excel', [DailyTimeRecordExportController::class, 'adviserExcel']);
    });

    Route::prefix('admin')->middleware(['auth:sanctum', 'role:Admin'])->group(function () {
        Route::get('/users', [UserManagementController::class, 'index']);
        Route::post('/users', [UserManagementController::class, 'store']);
        Route::delete('/users/{id}', [UserManagementController::class, 'destroy']);
        Route::get('/students/{id}/dtr/export/pdf', [DailyTimeRecordExportController::class, 'adminPdf']);
        Route::get('/students/{id}/dtr/export/excel', [DailyTimeRecordExportController::class, 'adminExcel']);
        Route::patch('/students/{id}/assign-adviser', [StudentAdviserController::class, 'assignAdviser']);
        Route::patch('/students/{id}/assign-supervisor', [StudentAdviserController::class, 'assignSupervisor']);
        Route::get('/students/{id}/adviser', [StudentAdviserController::class, 'getStudentAdviser']);
        Route::get('/students/{id}/supervisor', [StudentAdviserController::class, 'getStudentSupervisor']);
        Route::get('/advisers', [StudentAdviserController::class, 'getAdvisers']);
        Route::get('/supervisors', [StudentAdviserController::class, 'getSupervisors']);
    });

    Route::prefix('student')->middleware(['auth:sanctum', 'role:Student'])->group(function () {
        Route::post('/logs', [LogController::class, 'store']);
        Route::get('/logs', [LogController::class, 'index']);
        Route::get('/logs/{id}', [LogController::class, 'show']);
        Route::put('/logs/{id}', [LogController::class, 'update']);
        Route::post('/logs/{id}/attachments', [LogController::class, 'uploadAttachment'])
            ->middleware('throttle:10,1');
        Route::get('/logs/{id}/attachments/{attachmentId}', [LogController::class, 'downloadAttachment']);
    });




});
