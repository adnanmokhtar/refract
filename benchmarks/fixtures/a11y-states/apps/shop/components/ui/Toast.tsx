'use client';

import { useEffect, useState } from 'react';

// Lightweight inline notice used by the cart and wishlist for "added" confirmations.
export function Toast({ message, onDone }: { message: string | null; onDone: () => void }) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!message) return;
    setVisible(true);
    const id = setTimeout(() => {
      setVisible(false);
      onDone();
    }, 2500);
    return () => clearTimeout(id);
  }, [message, onDone]);

  if (!visible || !message) return null;

  return (
    <div className="fixed bottom-6 left-1/2 z-50 -translate-x-1/2 rounded-lg bg-foreground px-4 py-3 text-sm text-background shadow-lg">
      {message}
    </div>
  );
}
