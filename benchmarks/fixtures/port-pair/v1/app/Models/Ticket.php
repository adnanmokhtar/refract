<?php

namespace App\Models;

use App\Enums\TicketPriority;
use App\Enums\TicketStatus;
use App\Models\Scopes\AccountScope;
use App\Observers\TicketObserver;
use Illuminate\Database\Eloquent\Attributes\ObservedBy;
use Illuminate\Database\Eloquent\Attributes\ScopedBy;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[ScopedBy([AccountScope::class])]
#[ObservedBy([TicketObserver::class])]
class Ticket extends Model
{
    use SoftDeletes;

    protected $fillable = ['account_id', 'subject', 'body', 'status', 'priority', 'assignee_id', 'opened_by', 'order_id', 'due_at', 'closed_at'];

    protected $attributes = [
        'status' => 'open',
        'priority' => 2,
    ];

    protected $casts = [
        'status' => TicketStatus::class,
        'priority' => TicketPriority::class,
        'due_at' => 'datetime',
        'closed_at' => 'datetime',
    ];

    public function tags(): BelongsToMany
    {
        return $this->belongsToMany(Tag::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(TicketMessage::class);
    }

    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'subject' => $this->subject,
            'status' => $this->status->value,
            'priority' => $this->priority->value,
            'assignee_id' => $this->assignee_id,
            'tags' => $this->tags->pluck('name')->values(),
            'due_at' => $this->due_at?->toIso8601String(),
        ];
    }
}
