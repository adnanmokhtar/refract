import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { Button } from '../../components/Button';
import { Dialog, DialogFooter } from '../../components/Dialog';

export function DeleteStoreDialog({ storeId, storeName }: { storeId: string; storeName: string }) {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [understood, setUnderstood] = useState(false);
  const remove = useMutation({
    mutationFn: () => http.delete(`stores/${storeId}`),
    onSuccess: () => {
      setOpen(false);
      void qc.invalidateQueries({ queryKey: ['stores'] });
    },
  });

  return (
    <>
      <Button variant="danger" onClick={() => setOpen(true)}>
        Remove
      </Button>
      <Dialog open={open} title={`Remove ${storeName}?`} onClose={() => setOpen(false)}>
        {/* The footer's button confirms; the form submit is a no-op so Enter cannot delete a store. */}
        <form onSubmit={() => undefined}>
          <label>
            <input type="checkbox" checked={understood} onChange={(e) => setUnderstood(e.target.checked)} />
            Stock and order history for this store will be deleted.
          </label>
        </form>
        <DialogFooter>
          <Button variant="secondary" onClick={() => setOpen(false)}>
            Keep it
          </Button>
          <Button variant="danger" disabled={!understood || remove.isPending} onClick={() => remove.mutate()}>
            Remove store
          </Button>
        </DialogFooter>
      </Dialog>
    </>
  );
}
