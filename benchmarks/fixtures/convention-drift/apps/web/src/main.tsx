import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { RouterProvider, createRouter } from '@tanstack/react-router';
import { Provider } from 'react-redux';
import { Toaster } from 'sonner';
import '@acme/ui/tokens.css';
import { store } from './features/cart';
import { routeTree } from './routeTree.gen';

const router = createRouter({ routeTree });
const queryClient = new QueryClient();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Provider store={store}>
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
        <Toaster richColors />
      </QueryClientProvider>
    </Provider>
  </StrictMode>,
);
