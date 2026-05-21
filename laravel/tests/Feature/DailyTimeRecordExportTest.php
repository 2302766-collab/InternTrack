<?php

namespace Tests\Feature;

use App\Models\DailyTimeRecord;
use App\Models\InternshipProfile;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DailyTimeRecordExportTest extends TestCase
{
    use RefreshDatabase;

    public function test_student_can_export_monthly_dtr_as_csv(): void
    {
        $student = $this->createUserWithRole('Student', 'Juan Dela Cruz');
        $this->createDtr($student, '2026-04-01', '2026-04-01 08:00:00', '2026-04-01 12:00:00', '2026-04-01 13:00:00', '2026-04-01 17:00:00', 240, 240, 480);
        $this->createDtr($student, '2026-04-02', '2026-04-02 08:30:00', '2026-04-02 12:00:00', '2026-04-02 13:00:00', '2026-04-02 16:30:00', 210, 210, 420);

        Sanctum::actingAs($student);

        $response = $this->withHeader('Accept', 'text/csv')
            ->get('/api/v1/student/dtr/export/excel?month=4&year=2026');

        $response->assertOk();
        $response->assertHeader('Content-Type', 'text/csv; charset=UTF-8');
        $response->assertHeader('Content-Disposition', 'attachment; filename="dtr_juan_dela_cruz_2026_04.csv"');

        $content = $response->getContent();
        $this->assertStringContainsString('Internship Attendance Record', $content);
        $this->assertStringContainsString('STUDENT DAILY TIME RECORD', $content);
        $this->assertStringContainsString('Juan Dela Cruz', $content);
        $this->assertStringContainsString('08:00 AM', $content);
        $this->assertStringContainsString('1,"08:00 AM","12:00 PM","01:00 PM","05:00 PM",0,0', $content);
        $this->assertStringContainsString('2,"08:30 AM","12:00 PM","01:00 PM","04:30 PM",1,0', $content);

        $dayRows = preg_grep('/^[0-9]{1,2},/', preg_split("/\r\n|\n|\r/", $content) ?: []);
        $this->assertCount(30, $dayRows);
    }

    public function test_student_can_export_monthly_dtr_as_pdf(): void
    {
        $student = $this->createUserWithRole('Student', 'Ana Cruz');
        $this->createDtr($student, '2026-02-01', '2026-02-01 08:00:00', '2026-02-01 12:00:00', '2026-02-01 13:00:00', '2026-02-01 17:00:00', 240, 240, 480);

        Sanctum::actingAs($student);

        $response = $this->withHeader('Accept', 'application/pdf')
            ->get('/api/v1/student/dtr/export/pdf?month=2&year=2026');

        $response->assertOk();
        $response->assertHeader('Content-Type', 'application/pdf');
        $response->assertHeader('Content-Disposition', 'attachment; filename="dtr_ana_cruz_2026_02.pdf"');
        $this->assertStringStartsWith('%PDF-1.4', $response->getContent());
    }

    public function test_student_can_export_filtered_dtr_as_csv_without_changing_format(): void
    {
        $student = $this->createUserWithRole('Student', 'Juan Dela Cruz');
        $this->createDtr($student, '2026-04-01', '2026-04-01 08:00:00', '2026-04-01 12:00:00', '2026-04-01 13:00:00', '2026-04-01 17:00:00', 240, 240, 480);
        $this->createDtr($student, '2026-04-03', '2026-04-03 08:15:00', '2026-04-03 12:00:00', '2026-04-03 13:00:00', '2026-04-03 16:45:00', 225, 225, 450);

        Sanctum::actingAs($student);

        $response = $this->withHeader('Accept', 'text/csv')
            ->get('/api/v1/student/dtr/export/excel?start_date=2026-04-02&end_date=2026-04-03');

        $response->assertOk();
        $response->assertHeader('Content-Type', 'text/csv; charset=UTF-8');
        $response->assertHeader('Content-Disposition', 'attachment; filename="dtr_juan_dela_cruz_2026_04.csv"');

        $content = $response->getContent();
        $this->assertStringContainsString('"Month / Year","April 2026"', $content);
        $this->assertStringContainsString('1,,,,,,', $content);
        $this->assertStringContainsString('2,,,,,,', $content);
        $this->assertStringContainsString('3,"08:15 AM","12:00 PM","01:00 PM","04:45 PM",0,30', $content);

        $dayRows = preg_grep('/^[0-9]{1,2},/', preg_split("/\r\n|\n|\r/", $content) ?: []);
        $this->assertCount(30, $dayRows);
    }

    public function test_filtered_export_requires_start_and_end_dates_within_one_month(): void
    {
        $student = $this->createUserWithRole('Student', 'Ana Cruz');
        Sanctum::actingAs($student);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/dtr/export/excel?start_date=2026-04-30&end_date=2026-05-01')
            ->assertStatus(422)
            ->assertJsonPath(
                'data.errors.end_date.0',
                'Filtered exports must stay within a single month to preserve the DTR format.',
            );
    }

    public function test_supervisor_can_export_assigned_student_dtr_and_cannot_export_unassigned_student(): void
    {
        $supervisor = $this->createUserWithRole('Supervisor', 'Supervisor User');
        $otherSupervisor = $this->createUserWithRole('Supervisor', 'Other Supervisor');
        $assignedStudent = $this->createUserWithRole('Student', 'Assigned Student');
        $unassignedStudent = $this->createUserWithRole('Student', 'Unassigned Student');

        $this->createInternshipProfileFor($assignedStudent, $supervisor);
        $this->createInternshipProfileFor($unassignedStudent, $otherSupervisor);

        Sanctum::actingAs($supervisor);

        $this->get("/api/v1/supervisor/students/{$assignedStudent->id}/dtr/export/excel?month=4&year=2026")
            ->assertOk();

        $this->get("/api/v1/supervisor/students/{$unassignedStudent->id}/dtr/export/excel?month=4&year=2026")
            ->assertForbidden()
            ->assertJsonPath('message', 'You are not allowed to access this student\'s DTR export.');
    }

    public function test_student_can_view_monthly_dtr_rows_for_table_display(): void
    {
        $student = $this->createUserWithRole('Student', 'Table Student');
        $this->createInternshipProfileFor($student);
        $this->createDtr($student, '2026-04-02', '2026-04-02 08:10:00', '2026-04-02 12:02:00', '2026-04-02 13:05:00', '2026-04-02 17:01:00', 232, 236, 468);

        Sanctum::actingAs($student);

        $response = $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/student/dtr/monthly?month=4&year=2026');

        $response->assertOk()
            ->assertJsonPath('data.month', 4)
            ->assertJsonPath('data.year', 2026)
            ->assertJsonPath('data.student_name', 'Table Student')
            ->assertJsonPath('data.company_name', 'ABC Corp')
            ->assertJsonPath('data.rows.1.day', 2)
            ->assertJsonPath('data.rows.1.am_time_in_at', '2026-04-02T08:10:00+08:00')
            ->assertJsonPath('data.rows.1.am_time_out_at', '2026-04-02T12:02:00+08:00')
            ->assertJsonPath('data.rows.1.am_arrival', '08:10 AM')
            ->assertJsonPath('data.rows.1.am_departure', '12:02 PM')
            ->assertJsonPath('data.rows.1.lunch_out', '12:02 PM')
            ->assertJsonPath('data.rows.1.lunch_in', '01:05 PM')
            ->assertJsonPath('data.rows.1.pm_time_in_at', '2026-04-02T13:05:00+08:00')
            ->assertJsonPath('data.rows.1.pm_time_out_at', '2026-04-02T17:01:00+08:00')
            ->assertJsonPath('data.rows.1.pm_arrival', '01:05 PM')
            ->assertJsonPath('data.rows.1.pm_departure', '05:01 PM')
            ->assertJsonPath('data.rows.1.status', 'COMPLETED');

        $rows = $response->json('data.rows');
        $this->assertCount(30, $rows);
    }

    private function createUserWithRole(string $roleName, string $name): User
    {
        return User::factory()->create([
            'name' => $name,
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
        ]);
    }

    private function createInternshipProfileFor(User $student, ?User $supervisor = null): InternshipProfile
    {
        return InternshipProfile::create([
            'student_id' => $student->id,
            'supervisor_id' => $supervisor?->id,
            'company_name' => 'ABC Corp',
            'company_address' => '123 Main St',
            'required_hours' => 486,
            'start_date' => '2026-04-01',
            'end_date' => '2026-06-30',
        ]);
    }

    private function createDtr(
        User $student,
        string $date,
        string $timeIn,
        string $lunchOut,
        string $lunchIn,
        string $timeOut,
        int $firstMinutes,
        int $secondMinutes,
        int $totalMinutes
    ): DailyTimeRecord {
        return DailyTimeRecord::create([
            'student_id' => $student->id,
            'date' => $date,
            'time_in_at' => $timeIn,
            'lunch_out_at' => $lunchOut,
            'lunch_in_at' => $lunchIn,
            'time_out_at' => $timeOut,
            'first_work_minutes' => $firstMinutes,
            'second_work_minutes' => $secondMinutes,
            'total_work_minutes' => $totalMinutes,
            'status' => 'COMPLETED',
        ]);
    }
}
