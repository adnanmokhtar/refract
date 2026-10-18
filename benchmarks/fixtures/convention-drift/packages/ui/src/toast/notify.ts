import { toast } from 'sonner';

type NotifyOptions = { kind: 'info' | 'success' | 'error'; message: string };

// The design system's notification call: one place decides duration, icon and live region.
export function notify({ kind, message }: NotifyOptions) {
  if (kind === 'error') return toast.error(message, { duration: 8000 });
  if (kind === 'success') return toast.success(message);
  return toast(message);
}
