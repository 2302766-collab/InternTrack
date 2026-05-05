<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $unreadCount = Notification::query()
            ->where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        $notifications = Notification::query()
            ->where('user_id', $request->user()->id)
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate(20);

        return response()->json([
            'success' => true,
            'message' => 'Notifications retrieved successfully.',
            'data' => collect($notifications->items())->map(function (Notification $notification) {
                return [
                    'id' => $notification->id,
                    'title' => $notification->title,
                    'message' => $notification->message,
                    'is_read' => $notification->is_read,
                    'created_at' => $notification->created_at,
                ];
            })->values(),
            'meta' => [
                'current_page' => $notifications->currentPage(),
                'per_page' => $notifications->perPage(),
                'total' => $notifications->total(),
                'last_page' => $notifications->lastPage(),
                'has_more_pages' => $notifications->hasMorePages(),
                'unread_count' => $unreadCount,
            ],
        ], 200);
    }

    public function markAsRead(Request $request, int $id)
    {
        $notification = Notification::find($id);

        if (!$notification) {
            return response()->json([
                'success' => false,
                'message' => 'Notification not found.',
                'data' => null,
            ], 404);
        }

        if ($notification->user_id !== $request->user()->id) {
            return response()->json([
                'success' => false,
                'message' => 'You are not allowed to update this notification.',
                'data' => null,
            ], 403);
        }

        $notification->update([
            'is_read' => true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Notification marked as read.',
            'data' => [
                'id' => $notification->id,
                'title' => $notification->title,
                'message' => $notification->message,
                'is_read' => $notification->is_read,
                'created_at' => $notification->created_at,
            ],
        ], 200);
    }
}
