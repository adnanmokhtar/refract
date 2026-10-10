import { createContext, useContext, useState, type ReactNode } from 'react';

type Picks = {
  picked: Record<string, number>;
  markPicked: (lineId: string, quantity: number) => void;
};

const PickContext = createContext<Picks | null>(null);

export function PickProvider({ children }: { children: ReactNode }) {
  const [picked, setPicked] = useState<Record<string, number>>({});
  const markPicked = (lineId: string, quantity: number) => setPicked((current) => ({ ...current, [lineId]: quantity }));

  return <PickContext.Provider value={{ picked, markPicked }}>{children}</PickContext.Provider>;
}

export function usePicks(): Picks {
  const picks = useContext(PickContext);
  if (!picks) throw new Error('usePicks outside PickProvider');
  return picks;
}
