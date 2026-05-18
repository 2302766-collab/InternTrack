<?php

namespace Database\Seeders;

use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        $roles = Role::pluck('id', 'name');

        if (isset($roles['Admin'])) {
            User::updateOrCreate(
                ['email' => 'admin@example.com'],
                [
                    'name' => 'Sample Admin',
                    'gender' => 'Male',
                    'password' => Hash::make('password'),
                    'role_id' => $roles['Admin'],
                ],
            );
        }

        if (isset($roles['Student'])) {
            User::updateOrCreate(
                ['email' => 'student@example.com'],
                [
                    'name' => 'Sample Student',
                    'gender' => 'Female',
                    'password' => Hash::make('password'),
                    'role_id' => $roles['Student'],
                ],
            );
        }

        if (isset($roles['Supervisor'])) {
            User::updateOrCreate(
                ['email' => 'supervisor@example.com'],
                [
                    'name' => 'Sample Supervisor',
                    'gender' => 'Male',
                    'password' => Hash::make('password'),
                    'role_id' => $roles['Supervisor'],
                ],
            );
        }

        if (isset($roles['Adviser'])) {
            User::updateOrCreate(
                ['email' => 'adviser@example.com'],
                [
                    'name' => 'Sample Adviser',
                    'gender' => 'Female',
                    'password' => Hash::make('password'),
                    'role_id' => $roles['Adviser'],
                ],
            );
        }
    }
}
