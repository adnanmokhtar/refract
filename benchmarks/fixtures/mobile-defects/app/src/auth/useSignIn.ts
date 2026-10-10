import { router } from 'expo-router';

import { apiFetch } from '../api/http';
import { saveSession, type Session } from './session';

export function useSignIn() {
  return async function signIn(email: string, password: string): Promise<void> {
    const session = await apiFetch<Session>('/auth/session', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    await saveSession(session);
    // Replace, not push: Back from the home screen must never return to the sign-in form.
    router.replace('/');
  };
}
