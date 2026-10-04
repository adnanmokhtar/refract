import { FormEvent, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { api } from '../lib/api';
import { saveSession, SessionUser } from '../lib/session';

export function LoginPage() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    setBusy(true);
    setError(null);
    try {
      const { accessToken, user } = await api<{ accessToken: string; user: SessionUser }>('/auth/login', {
        method: 'POST',
        credentials: 'include',
        body: JSON.stringify({ email: form.get('email'), password: form.get('password') }),
      });
      saveSession(accessToken, user);
      const next = params.get('next');
      navigate(next && next.startsWith('/') && !next.startsWith('//') ? next : '/');
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="login" onSubmit={onSubmit}>
      <h1>Sign in</h1>
      {error && <p role="alert">{error}</p>}
      <label>
        Email
        <input name="email" type="email" autoComplete="email" required />
      </label>
      <label>
        Password
        <input name="password" type="password" autoComplete="current-password" required />
      </label>
      <button type="submit" disabled={busy}>
        Sign in
      </button>
    </form>
  );
}
