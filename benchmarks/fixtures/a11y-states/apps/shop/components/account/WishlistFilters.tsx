'use client';

import { useState } from 'react';
import { Chip } from '@/components/ui/Chip';

const ROOMS = ['living', 'bedroom', 'dining'] as const;

export function WishlistFilters({ onChange }: { onChange?: (rooms: string[]) => void }) {
  const [rooms, setRooms] = useState<string[]>([]);

  function toggle(room: string) {
    const next = rooms.includes(room) ? rooms.filter((r) => r !== room) : [...rooms, room];
    setRooms(next);
    onChange?.(next);
  }

  return (
    <div className="flex flex-wrap gap-2">
      {ROOMS.map((room) => (
        <Chip key={room} label={room} selected={rooms.includes(room)} onToggle={() => toggle(room)} />
      ))}
    </div>
  );
}
