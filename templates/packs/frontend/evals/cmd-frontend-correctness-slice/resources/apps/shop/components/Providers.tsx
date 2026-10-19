'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { setupWorker } from 'msw/browser';
import { useState } from 'react';
import { handlers } from '@/mocks/handlers';

// Demo and QA builds run against canned data: set NEXT_PUBLIC_API_MOCKING=enabled.
if (typeof window !== 'undefined' && process.env.NEXT_PUBLIC_API_MOCKING === 'enabled') {
  void setupWorker(...handlers).start({ onUnhandledRequest: 'bypass' });
}

export function Providers({ children }: { children: React.ReactNode }) {
  const [client] = useState(() => new QueryClient({ defaultOptions: { queries: { staleTime: 30_000 } } }));
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}
