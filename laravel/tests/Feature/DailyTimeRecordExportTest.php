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
        $this->assertStringContainsString('Civil Service Form No. 48', $content);
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
