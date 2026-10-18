import { createBrowserRouter } from 'react-router';
import { DashboardPage } from './pages/DashboardPage';
import { InvoicesPage } from './pages/InvoicesPage';
import { OrdersPage } from './pages/OrdersPage';
import { PlaceOrderPage } from './pages/PlaceOrderPage';
import { StatementsPage } from './pages/StatementsPage';
import { TicketDetailPage } from './pages/TicketDetailPage';
import { WalletPage } from './pages/WalletPage';

export const router = createBrowserRouter([
  { path: '/', element: <DashboardPage /> },
  { path: '/orders', element: <OrdersPage /> },
  { path: '/orders/new', element: <PlaceOrderPage /> },
  { path: '/invoices', element: <InvoicesPage /> },
  { path: '/wallet', element: <WalletPage /> },
  { path: '/wallet/statements', element: <StatementsPage /> },
  { path: '/tickets/:id', element: <TicketDetailPage /> },
]);
