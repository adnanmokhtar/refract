import { createBrowserRouter } from 'react-router';
import { TeamPage } from '../features/team/TeamPage';
import { IntegrationsPage } from '../features/stores/IntegrationsPage';
import { ApiKeysPage } from '../features/api-keys/ApiKeysPage';
import { AccountSettingsPage } from '../features/account/AccountSettingsPage';
import { PayoutsPage } from '../features/payouts/PayoutsPage';

export const router = createBrowserRouter([
  { path: '/team', element: <TeamPage /> },
  { path: '/stores/:storeId/integrations', element: <IntegrationsPage /> },
  { path: '/settings/api-keys', element: <ApiKeysPage /> },
  { path: '/settings/account', element: <AccountSettingsPage /> },
  { path: '/payouts', element: <PayoutsPage /> },
]);
