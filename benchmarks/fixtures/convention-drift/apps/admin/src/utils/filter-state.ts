import { createStore } from 'zustand/vanilla';

// Shared by the filter bar and the export dialog without going through a component.
export const filterState = createStore<{ status: string; setStatus: (status: string) => void }>((set) => ({
  status: 'all',
  setStatus: (status) => set({ status }),
}));
