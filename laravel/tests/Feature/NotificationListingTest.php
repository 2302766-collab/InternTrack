<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationListingTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_sees_only_own_notifications_sorted_newest_first(): void
    {
        $user = $this->createUserWithRole('Student');
        $otherUser = $this->createUserWithRole('Supervisor');

        $oldest = $this->createNotificationFor(
            $user,
            'Oldest',
            now()->subDays(2)
        );
        $newest = $this->createNotificationFor(
            $user,
            'Newest',
            now()->subHour()
        );
        $newest->update(['is_read' => true]);
        $middle = $this->createNotificationFor(
            $user,
            'Middle',
            now()->subDay()
        );

        $this->createNotificationFor($otherUser, 'Other User Notice', now());

        Sanctum::actingAs($user);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/notifications')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.id', $newest->id)
            ->assertJsonPath('data.1.id', $middle->id)
            ->assertJsonPath('data.2.id', $oldest->id)
            ->assertJsonPath('meta.unread_count', 2);
    }

    public function test_notifications_are_paginated_twenty_per_page(): void
    {
        $user = $this->createUserWithRole('Student');

        for ($i = 1; $i <= 21; $i++) {
            $this->createNotificationFor(
                $user,
                "Notice {$i}",
                now()->subMinutes($i)
            );
        }

        Sanctum::actingAs($user);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/notifications')
            ->assertOk()
            ->assertJsonCount(20, 'data')
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.per_page', 20)
            ->assertJsonPath('meta.total', 21)
            ->assertJsonPath('meta.last_page', 2)
            ->assertJsonPath('meta.has_more_pages', true);

        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/notifications?page=2')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('meta.current_page', 2)
            ->assertJsonPath('meta.has_more_pages', false);
    }

    public function test_unauthenticated_user_cannot_retrieve_notifications(): void
    {
        $this->withHeader('Accept', 'application/json')
            ->get('/api/v1/notifications')
            ->assertStatus(401)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    public function test_owner_can_mark_notification_as_read(): void
    {
        $user = $this->createUserWithRole('Student');
        $notification = $this->createNotificationFor(
            $user,
            'Unread Notice',
            now()->subMinute()
        );

        Sanctum::actingAs($user);

        $this->withHeader('Accept', 'application/json')
            ->patch("/api/v1/notifications/{$notification->id}/read")
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Notification marked as read.')
            ->assertJsonPath('data.id', $notification->id)
            ->assertJsonPath('data.is_read', true);

        $this->assertDatabaseHas('notifications', [
            'id' => $notification->id,
            'user_id' => $user->id,
            'is_read' => true,
        ]);
    }

    public function test_user_cannot_mark_other_users_notification_as_read(): void
    {
        $user = $this->createUserWithRole('Student');
        $otherUser = $this->createUserWithRole('Supervisor');
        $notification = $this->createNotificationFor(
            $otherUser,
            'Other Notice',
            now()->subMinute()
        );

        Sanctum::actingAs($user);

        $this->withHeader('Accept', 'application/json')
            ->patch("/api/v1/notifications/{$notification->id}/read")
            ->assertForbidden()
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'You are not allowed to update this notification.');
    }

    public function test_unauthenticated_user_cannot_mark_notification_as_read(): void
    {
        $user = $this->createUserWithRole('Student');
        $notification = $this->createNotificationFor(
            $user,
            'Notice',
            now()->subMinute()
        );

        $this->withHeader('Accept', 'application/json')
            ->patch("/api/v1/notifications/{$notification->id}/read")
            ->assertStatus(401)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    private function createUserWithRole(string $roleName): User
    {
        return User::factory()->create([
            'role_id' => Role::query()->firstOrCreate(['name' => $roleName])->id,
        ]);
    }

    private function createNotificationFor(
        User $user,
        string $title,
        \Illuminate\Support\Carbon $createdAt
    ): Notification {
        $notification = Notification::create([
            'user_id' => $user->id,
            'title' => $title,
            'message' => "{$title} message",
            'is_read' => false,
        ]);

        $notification->forceFill([
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ])->saveQuietly();

        return $notification->fresh();
    }
}
