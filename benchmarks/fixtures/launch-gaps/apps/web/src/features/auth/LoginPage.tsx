import { useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { useMutation } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { Button } from '../../components/Button';

export function LoginPage() {
  const navigate = useNavigate();
  const [form, setForm] = useState({ email: '', password: '' });
  const login = useMutation({ mutationFn: () => http.post('auth/login', { json: form }).json(), onSuccess: () => navigate('/') });
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        login.mutate();
      }}
    >
      <input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
      <input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} />
      <Button type="submit">Sign in</Button>
      <Link to="/signup">Create an account</Link>
    </form>
  );
}
