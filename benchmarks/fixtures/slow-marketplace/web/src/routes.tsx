import { lazy, Suspense } from 'react';
import { createBrowserRouter, Outlet } from 'react-router';
import { Layout } from './components/Layout';
import { RouteError } from './components/RouteError';
import { Spinner } from './components/Spinner';
import CatalogPage from './pages/CatalogPage';
import HomePage from './pages/HomePage';
import SellerAnalyticsPage from './pages/seller/SellerAnalyticsPage';

// Landing traffic arrives on Home and Catalog, so those two ship in the entry chunk.
// Everything behind sign-in, and the whole seller area, loads on demand: each lazy()
// route below is its own chunk.
const ProductPage = lazy(() => import('./pages/ProductPage'));
const CartPage = lazy(() => import('./pages/CartPage'));
const CheckoutPage = lazy(() => import('./pages/CheckoutPage'));
const AccountPage = lazy(() => import('./pages/AccountPage'));
const WishlistPage = lazy(() => import('./pages/WishlistPage'));
const SellerHomePage = lazy(() => import('./pages/seller/SellerHomePage'));
const SellerProductsPage = lazy(() => import('./pages/seller/SellerProductsPage'));
const SellerOrdersPage = lazy(() => import('./pages/seller/SellerOrdersPage'));
const SellerSettingsPage = lazy(() => import('./pages/seller/SellerSettingsPage'));
const OrdersPage = lazy(() => import('./pages/OrdersPage'));

const Shell = () => (
  <Layout>
    <Suspense fallback={<Spinner />}>
      <Outlet />
    </Suspense>
  </Layout>
);

export const router = createBrowserRouter([
  {
    element: <Shell />,
    errorElement: <RouteError />,
    children: [
      { path: '/', element: <HomePage /> },
      { path: '/c/:category', element: <CatalogPage /> },
      { path: '/s/:storeSlug/p/:slug', element: <ProductPage /> },
      { path: '/cart', element: <CartPage /> },
      { path: '/checkout', element: <CheckoutPage /> },
      { path: '/account', element: <AccountPage /> },
      { path: '/account/orders', element: <OrdersPage /> },
      { path: '/account/wishlist', element: <WishlistPage /> },
      {
        path: '/seller/:storeId',
        children: [
          { index: true, element: <SellerHomePage /> },
          { path: 'analytics', element: <SellerAnalyticsPage /> },
          { path: 'products', element: <SellerProductsPage /> },
          { path: 'orders', element: <SellerOrdersPage /> },
          { path: 'settings', element: <SellerSettingsPage /> },
        ],
      },
    ],
  },
]);
