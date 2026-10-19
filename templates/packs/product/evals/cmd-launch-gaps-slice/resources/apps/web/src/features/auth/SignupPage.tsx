import { useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { useMutation } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useTracking } from '../../shared/tracking/TrackingProvider';
import { Button } from '../../components/Button';

export function SignupPage() {
  const navigate = useNavigate();
  const { trackEvent } = useTracking();
  const [form, setForm] = useState({ email: '', password: '', storeName: '' });
  // The account exists once the API answers 201; the verification e-mail goes out from there.
  const signup = useMutation({
    mutationFn: () => http.post('auth/signup', { json: form }).json(),
    onSuccess: () => navigate('/onboarding/welcome'),
  });
  return (
    <section>
      <h1>Start your free trial</h1>
      <input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
      <input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} />
      <input value={form.storeName} onChange={(e) => setForm({ ...form, storeName: e.target.value })} />
      <Button
        disabled={signup.isPending}
        onClick={() => {
          trackEvent('Signup Completed', { method: 'email' });
          signup.mutate();
        }}
      >
        Create account
      </Button>
      {signup.isError && <p role="alert">We could not create the account. Check the e-mail and try again.</p>}
      <Link to="/login">I already have an account</Link>
    </section>
  );
}
