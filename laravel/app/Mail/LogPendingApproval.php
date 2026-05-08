<?php

namespace App\Mail;

use App\Models\LogEntry;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class LogPendingApproval extends Mailable
{
    use Queueable, SerializesModels;

    /**
     * Create a new message instance.
     */
    public function __construct(
        public readonly LogEntry $log,
        public readonly User $supervisor,
    ) {
    }

    /**
     * Get the message envelope.
     */
    public function envelope(): Envelope
    {
        return new Envelope(
            subject: "New Log Submitted for Review - {$this->log->date}",
        );
    }

    /**
     * Get the message content definition.
     */
    public function content(): Content
    {
        return new Content(
            view: 'emails.log_pending_approval',
            with: [
                'log' => $this->log,
                'student' => $this->log->internshipProfile?->student,
                'supervisor' => $this->supervisor,
            ],
        );
    }

    /**
     * Get the attachments for the message.
     *
     * @return array<int, \Illuminate\Mail\Mailables\Attachment>
     */
    public function attachments(): array
    {
        return [];
    }

    public function build(): static
    {
        return $this
            ->subject($this->envelope()->subject)
            ->view('emails.log_pending_approval')
            ->with($this->content()->with);
    }
}
