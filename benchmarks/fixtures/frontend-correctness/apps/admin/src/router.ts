import { createRouter, createWebHistory } from 'vue-router';

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/dispatch' },
    { path: '/login', component: () => import('./views/LoginView.vue') },
    { path: '/dispatch', component: () => import('./views/DispatchView.vue') },
    { path: '/orders', component: () => import('./views/OrdersView.vue') },
    { path: '/orders/:id', component: () => import('./views/OrderDetailView.vue') },
    { path: '/pickers', component: () => import('./views/PickersView.vue') },
    { path: '/pickers/:id', component: () => import('./views/PickerDetailView.vue') },
    { path: '/customers', component: () => import('./views/CustomerSearchView.vue') },
    { path: '/reports', component: () => import('./views/ReportsView.vue') },
    { path: '/settings', component: () => import('./views/SettingsView.vue') },
  ],
});
