import { useNavigate, useParams } from 'react-router';
import { useMutation } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useTracking } from '../../shared/tracking/TrackingProvider';
import { Button } from '../../components/Button';

export function AcceptInvitePage() {
  const { token = '' } = useParams();
  const navigate = useNavigate();
  const { trackEvent } = useTracking();
  const accept = useMutation({ mutationFn: () => http.post(`team/invites/${token}/accept`).json<{ role: string }>() });

  async function join() {
    const invite = await accept.mutateAsync();
    trackEvent('Invite Accepted', { role: invite.role });
    trackEvent('signup_completed', { method: 'invite' });
    navigate('/');
  }

  return (
    <section>
      <h1>You have been invited to Shelfwise</h1>
      <Button onClick={() => void join()} disabled={accept.isPending}>
        Join the team
      </Button>
    </section>
  );
}
