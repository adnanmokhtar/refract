import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'stores' },
  { path: 'stores', loadComponent: () => import('./store-locator.component').then((m) => m.StoreLocatorComponent) },
  { path: 'reviews/:sku', loadComponent: () => import('./review-summary.component').then((m) => m.ReviewSummaryComponent) },
  { path: 'newsletter', loadComponent: () => import('./newsletter.component').then((m) => m.NewsletterComponent) },
  { path: '**', redirectTo: 'stores' },
];
