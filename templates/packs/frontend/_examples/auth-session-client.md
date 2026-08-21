---
name: auth-session-client
kind: example
pack: frontend
---

# Pattern: Auth Session (client)

One module owns the session: where the credential lives, how it refreshes, how it is destroyed. A component reading `localStorage.getItem('token')` directly is a second owner, and that is the bug.

**Boundary.** This is the CLIENT half. Token issuance, rotation policy and revocation belong to the backend pack. The *test harness's* session (`tests/.auth/user.json`, the Playwright `setup` project) is `visual-check`'s and is a different thing wearing the same word.

## Where the token lives — the trade, not a verdict

| Option | Buys | Costs |
|---|---|---|
| httpOnly cookie | script can't read it (XSS can't exfiltrate); server sees it, so SSR personalises the first paint | CSRF surface: `SameSite` + origin/token check on state-changing requests |
| In-memory | nothing on disk; smallest XSS window | gone on reload/new tab — needs a refresh cookie, accepts a "restoring session" state |
| localStorage | readable anywhere, survives reload, any API host | ANY XSS reads it, including one in a dependency you didn't write; invisible to SSR |

Write the choice into an ADR with the threat model. Non-negotiable either way: exactly one module touches it.

## The 401 stampede

Six components mount, the access token has just expired, six 401s return. Without a single-flight gate that is six refresh calls — and against a backend that rotates refresh tokens, five of them present an already-rotated token and log the user out mid-session. It reads as "random logouts" and only reproduces under concurrency.

```ts
let inFlight: Promise<void> | null = null;
const refreshOnce = () => (inFlight ??= api.refresh().finally(() => { inFlight = null; }));

onResponseError(async (error, request) => {
  if (error.status !== 401 || request.retried) throw error;   // retry exactly once
  await refreshOnce();                                         // queue behind the one refresh
  return retry({ ...request, retried: true });
});
```

Clear the promise in `finally` (a rejected refresh must not poison later requests); keep the retry flag per-request; and run the full logout teardown when refresh fails.

## Logout is a fan-out, not a token delete

Credential (server-side too, not just the client copy) → abort in-flight requests → **clear** (not invalidate) the query cache → reset user-scoped stores → close sockets → broadcast to other tabs → then navigate. Skip step 3 and the next user on a shared device sees the previous user's lists.

## Cross-tab

`BroadcastChannel('auth')`, with the `storage` event as fallback (it fires in *other* tabs only — exactly the semantics you want). Broadcast the event (`logged-out`, `switched-user`), never the token.

## Route guard, not render guard

`{user && <Dashboard/>}` decides after the route mounted and the effects ran. Guard in the router, and model three states — `unknown | authenticated | anonymous`. Collapsing `unknown` into `anonymous` is the login-flash; collapsing it into `authenticated` is the protected-content flash.

## Accessible authentication (WCAG 2.2 SC 3.3.8)

Paste MUST work in password / OTP fields; real `autocomplete` values, never `autocomplete="off"` on a credential field; no cognitive-function test as the only path; login errors announced per `forms.md`.

## Detectors (abridged)

1. `rg -n "(localStorage|sessionStorage)\.(get|set|remove)Item\(\s*['\"][^'\"]*(token|jwt|auth|session)"` — every hit outside the session module.
2. refresh call sites with no module-level in-flight holder (`rg -n 'let\s+(refreshing|refreshPromise|inFlight)'`).
3. `logout` bodies that clear the token and nothing else.
4. zero hits for `BroadcastChannel|addEventListener\(['"]storage` in an app holding session state.
5. protected route with no router-guard entry.
6. `type="password"` with `onPaste` prevention, or with no `autocomplete`.
7. `rg -n '[?&](token|access_token|jwt)='` — credential in a URL is a credential in the analytics payload.
