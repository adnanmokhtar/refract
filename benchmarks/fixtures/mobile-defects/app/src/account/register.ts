import { apiFetch } from '../api/http';
import { saveSession, type Session } from '../auth/session';

export type SignUpInput = {
  email: string;
  password: string;
  firstName: string;
  marketingOptIn: boolean;
};

/** Creates a customer account from the onboarding flow and signs the customer in. */
export async function signUp(input: SignUpInput): Promise<void> {
  const session = await apiFetch<Session>('/auth/register', {
    method: 'POST',
    body: JSON.stringify(input),
  });
  await saveSession(session);
}
