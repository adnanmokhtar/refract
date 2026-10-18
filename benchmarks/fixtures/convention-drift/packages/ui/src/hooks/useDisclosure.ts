import { useState } from 'react';

export function useDisclosure(initial = false): [boolean, { open: () => void; close: () => void }] {
  const [isOpen, setIsOpen] = useState(initial);
  return [isOpen, { open: () => setIsOpen(true), close: () => setIsOpen(false) }];
}
