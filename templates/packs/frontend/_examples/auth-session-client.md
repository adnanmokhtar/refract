---
name: auth-session-client
kind: example
pack: frontend
---

# Pattern: Auth Session (client)

> **Hard rule:** The session has exactly ONE owner in the client — a single module that knows where the credential lives, how it refreshes, and how it is destroyed. Every read goes through that module; a component reading `localStorage.getItem('token')` directly is forbidden. Refresh is **single-flight** (N concurrent 401s trigger ONE refresh, the rest queue behind it), logout invalidates **every** cache and in-flight request rather than just the token, and no route renders protected content before the guard has resolved. Cite the token-storage site, the refresh interceptor, and the logout path at `<file:line>` + the missing stage + the fix — a session claim without those three citations is a vibe, not a finding.

**Halt conditions / mandatory cites**
- Any storage recommendation MUST state the trade it accepts (XSS blast radius vs CSRF surface vs SSR readability), not just the verdict. "Use httpOnly cookies" with no threat model is advice, not a decision.
- Any refresh claim MUST cite the single-flight mechanism at `<file:line>`. "It refreshes" without the queue is the stampede bug, not the fix.
- Any logout claim MUST enumerate what is invalidated: token, query cache, in-flight requests, socket, cross-tab broadcast. A logout that clears one of five is a data-leak between users on a shared device.
- A route-guard claim MUST cite the guard AND what renders while it resolves. "It redirects" says nothing about the frame before the redirect.
- If the project already has a session module / auth SDK / interceptor, mirror it. Introducing a second place that knows about tokens is the failure this pattern exists to prevent.
- Hand-wave grep on `etc.`, `...`, `handles auth`, `probably refreshes` is forbidden — re-enumerate each call site.

One module owns the session: where the credential lives, how it refreshes, how it is destroyed. A component reading `localStorage.getItem('token')` directly is a second owner, and that is the bug.

**Boundary.** This is the CLIENT half. Token issuance, rotation policy and revocation belong to the backend pack. The *test harness's* session (`tests/.auth/user.json`, the Playwright `setup` project) is `visual-check`'s and is a different thing wearing the same word.

## Where the token lives — the trade, not a verdict

| Option | Buys | Costs |
|---|---|---|
| httpOnly cookie | script can't read it (XSS can't exfiltrate); server sees it, so SSR personalises the first paint | CSRF surface: `SameSite` + origin/token check on state-changing requests |
| In-memory | nothing on disk; smallest XSS window | gone on reload/new tab — needs a refresh cookie, accepts a "restoring session" state |
| localStorage | readable anywhere, survives reload, any API host | ANY XSS reads it, including one in a dependency you didn't write; invisible to SSR |

Write the choice into an ADR with the threat model. Non-negotiable either way: exactly one module touches it.

## Mid-migration (SPA+bearer → BFF, cookie → token)

The row the other six cannot answer, and the state an app lives in for weeks. **The session module stays singular; only its source becomes a branch** — one `session.get()`, one refresh path, one logout fan-out, with one internal branch per transport. **Refresh belongs to whichever side holds the refresh credential, and only one side may** — both sides refreshing against a rotating token is the 401 stampede with two participants who cannot see each other, and it produces "random logouts" with no concurrency in the app to explain it. **Logout fans out over both transports** until the old one is deleted, in the same change that deletes it.

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
