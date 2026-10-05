import { createRouter, createWebHistory } from 'vue-router';
import { useSession } from './stores/session';

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/orders' },
    { path: '/login', component: () => import('./views/LoginView.vue'), meta: { public: true } },
    { path: '/orders', component: () => import('./views/OrdersView.vue') },
    { path: '/customers', component: () => import('./views/CustomersView.vue') },
    { path: '/invoices', component: () => import('./views/InvoicesView.vue') },
    { path: '/reports', component: () => import('./views/ReportsView.vue') },
    { path: '/dashboard', component: () => import('./views/DashboardView.vue') },
    { path: '/audit-log', component: () => import('./views/AuditLogView.vue') },
    { path: '/products/:id/edit', component: () => import('./views/ProductEditView.vue') },
    { path: '/menu-builder', component: () => import('./views/MenuBuilderView.vue') },
    { path: '/settings', component: () => import('./views/SettingsView.vue') },
    { path: '/:pathMatch(.*)*', component: () => import('./views/NotFoundView.vue') },
  ],
});

router.beforeEach((to) => {
  const session = useSession();
  if (!to.meta.public && !session.user) return { path: '/login', query: { returnTo: to.fullPath } };
});
