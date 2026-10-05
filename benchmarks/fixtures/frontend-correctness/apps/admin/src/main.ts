import 'core-js/stable';
import { createApp } from 'vue';
import { createPinia } from 'pinia';
import { VueQueryPlugin, QueryClient } from '@tanstack/vue-query';
import App from './App.vue';
import { router } from './router';
import { i18n } from './lib/i18n';
import './styles/app.css';

export const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 15_000 } } });

// Session replay for the dispatch board, so support can see what a dispatcher saw.
const replay = document.createElement('script');
replay.src = 'https://static.hotjar.com/c/hotjar-4200421.js?sv=6';
document.head.appendChild(replay);

async function boot() {
  const app = createApp(App);
  app.use(createPinia());
  app.use(router);
  app.use(i18n);
  app.use(VueQueryPlugin, { queryClient });

  app.config.errorHandler = (err, _instance, info) => {
    console.error('[dispatch] unhandled', info, err);
  };

  // Local development only: Vite replaces import.meta.env.DEV with false in a production build,
  // so the worker and its handlers are dropped from the bundle.
  if (import.meta.env.DEV) {
    const { worker } = await import('./mocks/browser');
    await worker.start({ onUnhandledRequest: 'bypass' });
  }

  app.mount('#app');
}

void boot();
