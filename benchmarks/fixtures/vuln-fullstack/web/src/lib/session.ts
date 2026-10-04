// Client-side session: the access token returned by POST /api/auth/login and the user it
// belongs to. Kept across reloads so buyers stay signed in between visits.

export interface SessionUser {
  id: string;
  email: string;
  role: 'BUYER' | 'SELLER' | 'ADMIN';
  displayName: string;
}

const TOKEN_KEY = 'mk_access_token';
const USER_KEY = 'mk_user';

export function saveSession(token: string, user: SessionUser) {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function getUser(): SessionUser | null {
  const raw = localStorage.getItem(USER_KEY);
  return raw ? (JSON.parse(raw) as SessionUser) : null;
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
}
