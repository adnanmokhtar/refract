import { Outlet } from 'react-router';
import { TrackingProvider } from '../shared/tracking/TrackingProvider';
import { useSession } from '../shared/session/use-session';

export function Root() {
  const session = useSession();
  const user = session.data ? { id: session.data.id, email: session.data.email } : null;
  return (
    <TrackingProvider user={user}>
      <Outlet />
    </TrackingProvider>
  );
}
