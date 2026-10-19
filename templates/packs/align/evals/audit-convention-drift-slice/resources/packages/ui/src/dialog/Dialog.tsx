import * as RadixDialog from '@radix-ui/react-dialog';
import type { ReactNode } from 'react';
import styles from './Dialog.module.css';

// The wrappers re-export Radix's parts with their own props: `Dialog` is `Root`, unchanged.
export const Dialog = RadixDialog.Root;
export const DialogTrigger = RadixDialog.Trigger;
export const DialogClose = RadixDialog.Close;
export const DialogTitle = RadixDialog.Title;

export function DialogContent({ children }: { children: ReactNode }) {
  return (
    <RadixDialog.Portal>
      <RadixDialog.Overlay className={styles.overlay} />
      <RadixDialog.Content className={styles.content}>{children}</RadixDialog.Content>
    </RadixDialog.Portal>
  );
}
