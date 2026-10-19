import { createContext, useCallback, useContext, useEffect, useRef, type ReactNode } from 'react';
import posthog from 'posthog-js';
import { http } from '../api/http';

declare global {
  interface Window {
    fbq?: (cmd: 'track' | 'trackCustom', name: string, data?: object, opts?: { eventID: string }) => void;
  }
}

export interface TrackingUser {
  id: string;
  email: string;
}

/**
 * The Meta pixel only runs for visitors who are not signed in (marketing pages, signup). For a
 * signed-in merchant the Conversions API leg below delivers the same event with the same id.
 */
function sendPixel(name: string, data: object | undefined, eventId: string, user: TrackingUser | null) {
  if (user) return;
  window.fbq?.('trackCustom', name, data, { eventID: eventId });
}

/** Server leg: the API forwards to the Conversions API and hashes identifiers first (apps/api/src/events/capi.ts). */
function sendServerLeg(name: string, data: object | undefined, eventId: string, user: TrackingUser | null) {
  void http.post('events', { json: { name, data, event_id: eventId, email: user?.email } }).catch(() => undefined);
}

interface TrackingContextValue {
  trackEvent: (eventName: string, data?: Record<string, unknown>) => void;
}

const TrackingContext = createContext<TrackingContextValue | null>(null);

export function TrackingProvider({ user, children }: { user: TrackingUser | null; children: ReactNode }) {
  const userRef = useRef(user);
  useEffect(() => {
    userRef.current = user;
    if (user) posthog.identify(user.id);
  }, [user]);

  // Stable for the app's lifetime (it reads the user through a ref), so effects that list it run once.
  const trackEvent = useCallback((eventName: string, data?: Record<string, unknown>) => {
    const eventId = crypto.randomUUID();
    posthog.capture(eventName, { ...data, event_id: eventId });
    sendPixel(eventName, data, eventId, userRef.current);
    sendServerLeg(eventName, data, eventId, userRef.current);
  }, []);

  return <TrackingContext.Provider value={{ trackEvent }}>{children}</TrackingContext.Provider>;
}

export function useTracking(): TrackingContextValue {
  const ctx = useContext(TrackingContext);
  if (!ctx) throw new Error('useTracking must be used inside TrackingProvider');
  return ctx;
}
