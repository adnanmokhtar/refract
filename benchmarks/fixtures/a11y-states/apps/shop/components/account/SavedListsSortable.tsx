'use client';

import { DndContext, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from '@dnd-kit/core';
import { SortableContext, arrayMove, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable';
import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { GripVertical } from 'lucide-react';
import { api } from '@/lib/api';
import { ConfirmDeleteDialog } from './ConfirmDeleteDialog';

type SavedList = { id: string; name: string; count: number };

function ListRow({ list, onDelete }: { list: SavedList; onDelete: (list: SavedList) => void }) {
  const t = useTranslations('common');
  const { attributes, listeners, setNodeRef, transform } = useSortable({ id: list.id });
  const style = transform ? { transform: `translate3d(0, ${transform.y}px, 0)` } : undefined;

  return (
    <li ref={setNodeRef} style={style} className="flex items-center gap-3 rounded-lg border bg-background px-3 py-2">
      <span {...attributes} {...listeners} className="cursor-grab text-muted-foreground">
        <GripVertical aria-hidden className="size-4" />
      </span>
      <span className="flex-1 text-sm">{list.name}</span>
      <button type="button" className="text-sm text-destructive underline" onClick={() => onDelete(list)}>
        {t('delete')}
      </button>
    </li>
  );
}

export function SavedListsSortable({ initial = [] }: { initial?: SavedList[] }) {
  const t = useTranslations('account');
  const [lists, setLists] = useState(initial);
  const [pendingDelete, setPendingDelete] = useState<SavedList | null>(null);
  const sensors = useSensors(useSensor(PointerSensor));

  function onDragEnd({ active, over }: DragEndEvent) {
    if (!over || active.id === over.id) return;
    const from = lists.findIndex((l) => l.id === active.id);
    const to = lists.findIndex((l) => l.id === over.id);
    const next = arrayMove(lists, from, to);
    setLists(next);
    void api.put('/me/lists/order', { ids: next.map((l) => l.id) });
  }

  return (
    <section aria-labelledby="lists-heading">
      <h2 id="lists-heading" className="text-lg font-semibold">
        {t('lists')}
      </h2>
      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
        <SortableContext items={lists} strategy={verticalListSortingStrategy}>
          <ul className="mt-4 space-y-2">
            {lists.map((list) => (
              <ListRow key={list.id} list={list} onDelete={setPendingDelete} />
            ))}
          </ul>
        </SortableContext>
      </DndContext>
      <ConfirmDeleteDialog
        open={pendingDelete !== null}
        title={t('deleteList')}
        onCancel={() => setPendingDelete(null)}
        onConfirm={async () => {
          if (!pendingDelete) return;
          await api.del(`/me/lists/${pendingDelete.id}`);
          setLists((all) => all.filter((l) => l.id !== pendingDelete.id));
          setPendingDelete(null);
        }}
      />
    </section>
  );
}
