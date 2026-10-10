/**
 * Store managers invite new staff by e-mail. The invite link opens this app and signs the device in with the
 * one-time token it carries; the sign-in screen is skipped.
 */
export const INVITE_LINK_PREFIX = 'pantrypicker://login?token=';

export function parseInvite(url: string): string | null {
  if (!url.startsWith(INVITE_LINK_PREFIX)) return null;
  return decodeURIComponent(url.slice(INVITE_LINK_PREFIX.length));
}
