import { Navigate, Outlet } from 'react-router';
import { useSession } from '../shared/session/use-session';
import { Sidebar } from './Sidebar';
import { TrialBanner } from '../features/billing/TrialBanner';

export function AppLayout() {
  const session = useSession();
  if (session.isPending) return null;
  if (!session.data) return <Navigate to="/login" replace />;
  return (
    <div className="app-shell">
      <Sidebar />
      <main>
        <TrialBanner />
        <Outlet />
      </main>
    </div>
  );
}
