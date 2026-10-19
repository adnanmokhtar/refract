import { createBrowserRouter } from 'react-router';
import { Root } from './Root';
import { AppLayout } from '../layout/AppLayout';
import { NotFound } from '../components/NotFound';
import { LoginPage } from '../features/auth/LoginPage';
import { SignupPage } from '../features/auth/SignupPage';
import { AcceptInvitePage } from '../features/team/AcceptInvitePage';
import { WelcomePage } from '../features/onboarding/WelcomePage';
import { ConnectStoreStep } from '../features/onboarding/ConnectStoreStep';
import { DashboardPage } from '../features/dashboard/DashboardPage';
import { OrdersPage } from '../features/orders/OrdersPage';
import { OrderDetail } from '../features/orders/OrderDetail';
import { StoresPage } from '../features/stores/StoresPage';
import { ReportsPage } from '../features/reports/ReportsPage';
import { InboxPage } from '../features/inbox/InboxPage';
import { LoyaltyPage } from '../features/loyalty/LoyaltyPage';
import { GiftCardsPage } from '../features/gift-cards/GiftCardsPage';
import { ImportPage } from '../features/imports/ImportPage';
import { AssistantPage } from '../features/assistant/AssistantPage';
import { ReferralsPage } from '../features/referrals/ReferralsPage';
import { TeamPage } from '../features/team/TeamPage';
import { SettingsPage } from '../features/settings/SettingsPage';
import { UpgradePage } from '../features/billing/UpgradePage';

export const router = createBrowserRouter([
  {
    element: <Root />,
    children: [
      { path: '/login', element: <LoginPage /> },
      { path: '/signup', element: <SignupPage /> },
      { path: '/invite/:token', element: <AcceptInvitePage /> },
      { path: '/onboarding/welcome', element: <WelcomePage /> },
      { path: '/onboarding/connect', element: <ConnectStoreStep /> },
      {
        path: '/',
        element: <AppLayout />,
        children: [
          { index: true, element: <DashboardPage /> },
          { path: 'orders', element: <OrdersPage /> },
          { path: 'orders/:orderId', element: <OrderDetail /> },
          { path: 'stores', element: <StoresPage /> },
          { path: 'reports', element: <ReportsPage /> },
          { path: 'inbox', element: <InboxPage /> },
          { path: 'loyalty', element: <LoyaltyPage /> },
          { path: 'gift-cards', element: <GiftCardsPage /> },
          { path: 'imports', element: <ImportPage /> },
          { path: 'assistant', element: <AssistantPage /> },
          { path: 'referrals', element: <ReferralsPage /> },
          { path: 'team', element: <TeamPage /> },
          { path: 'settings', element: <SettingsPage /> },
          { path: 'billing/upgrade', element: <UpgradePage /> },
        ],
      },
      { path: '*', element: <NotFound /> },
    ],
  },
]);
