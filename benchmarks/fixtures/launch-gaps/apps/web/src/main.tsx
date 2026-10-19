import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { RouterProvider } from 'react-router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import posthog from 'posthog-js';
import './i18n';
import { router } from './app/router';

posthog.init(import.meta.env.VITE_POSTHOG_KEY, { api_host: 'https://eu.i.posthog.com', capture_pageview: 'history_change' });

const queryClient = new QueryClient();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </StrictMode>,
);
