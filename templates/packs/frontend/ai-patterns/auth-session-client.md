---
name: auth-session-client
description: "Pattern: the CLIENT half of a login session — where the token lives and what that choice costs, single-flight silent refresh (the 401 stampede), logout that invalidates every cache and in-flight request, cross-tab sync, route-guard vs render-guard and the flash of protected content, and the WCAG 2.2 accessible-authentication floor. The client complement to the backend pack's token issuance, rotation and revocation."
kind: ai-pattern
pack: frontend
---

# Pattern: Auth Session (client)

> **Hard rule:** The session has exactly ONE owner in the client — a single module that knows where the credential lives, how it refreshes, and how it is destroyed. Every read goes through that module; a component reading `localStorage.getItem('token')` directly is forbidden. Refresh is **single-flight** (N concurrent 401s trigger ONE refresh, the rest queue behind it), logout invalidates **every** cache and in-flight request rather than just the token, and no route renders protected content before the guard has resolved. Cite the token-storage site, the refresh interceptor, and the logout path at `<file:line>` + the missing stage + the fix — a session claim without those three citations is a vibe, not a finding.

**Ownership boundary.** This pattern owns the **client's** session lifecycle: storage, refresh, propagation, teardown, and the login form's accessibility. **Token issuance, rotation policy, revocation, and the refresh endpoint's replay defence are the backend pack's** (`api-contract`, `error-handling`, the auth rules there) — do not re-derive server-side token design here; state the contract you consume (lifetime, refresh mechanism, error codes) and cite it. Separately, the **test harness's** auth session — `tests/.auth/user.json`, the Playwright `setup` project — belongs to the `visual-check` skill and is a different thing wearing the same word: it exists so a screenshot is not the login page. Confusing the two produces a "fix" to the app's session that was really a stale storage-state file.

**When to apply**
- The app has a login and any route, action, or data read that depends on it.
- A session bug is reported: users randomly logged out, a stale user shown after logout, a burst of refresh calls, a tab that never noticed the other tab logged out.
- Auth is being added, or its storage is being changed (cookie to token, token to cookie, adding a BFF).

**When NOT to apply**
- The app has no authentication at all, or auth is fully delegated to a hosted SDK that owns storage + refresh + cross-tab sync end to end — in that case mirror the SDK's primitives and cite them; do not hand-roll a second session.
- Authorization *rules* (who may do what) — that is a different concern; this pattern only establishes **who the user is** and keeps that fact fresh.
- Server-side session handling in a server-rendered route: the request-scoped read belongs to `ssr-safety.md`'s per-request accessor rule.

**Halt conditions / mandatory cites**
- Any storage recommendation MUST state the trade it accepts (XSS blast radius vs CSRF surface vs SSR readability), not just the verdict. "Use httpOnly cookies" with no threat model is advice, not a decision.
- Any refresh claim MUST cite the single-flight mechanism at `<file:line>`. "It refreshes" without the queue is the stampede bug, not the fix.
- Any logout claim MUST enumerate what is invalidated: token, query cache, in-flight requests, socket, cross-tab broadcast. A logout that clears one of five is a data-leak between users on a shared device.
- A route-guard claim MUST cite the guard AND what renders while it resolves. "It redirects" says nothing about the frame before the redirect.
- If the project already has a session module / auth SDK / interceptor, mirror it. Introducing a second place that knows about tokens is the failure this pattern exists to prevent.
- Hand-wave grep on `etc.`, `...`, `handles auth`, `probably refreshes` is forbidden — re-enumerate each call site.

## Adapt to the codebase

Detect where the credential already lives before proposing anything; the right answer is usually "the one the project already has, done completely."

| Stack | Typical session transport | Guard placement | Where refresh belongs |
|---|---|---|---|
| **Next (App Router)** | httpOnly cookie set by a route handler / server action; read on the server | `proxy.ts` (formerly `middleware.ts`) + a server-side check in the layout | server-side on the cookie; the client never sees the refresh token |
| **Nuxt** | httpOnly cookie + server route, or `useCookie` for a readable claim set | route middleware (`definePageMeta`) | Nitro server route; client composable only triggers it |
| **SvelteKit** | httpOnly cookie read in `hooks.server.ts` into `locals` | `+layout.server.ts` load guard | server hook on the cookie |
| **Angular** | `HttpInterceptor` + a session service (in-memory access token) | route `CanActivate` guard | the interceptor, with one shared in-flight refresh |
| **SPA + BFF** | cookie to the BFF; the BFF holds the real token | router guard + BFF 401 handling | the BFF; the SPA only retries |
| **SPA + bearer token** | in-memory access token + httpOnly refresh cookie | router guard | the HTTP client's response interceptor |

| **Mid-migration** (SPA+bearer → BFF, or cookie → token) | **both, concurrently** — the old transport still serves some routes | the router guard, reading ONE resolved session, never two | see below |

Whatever the row, **one module owns it**. Components ask that module; they never ask the browser.

**The migration row is the one this pattern is most often opened during, and it is the row the other six cannot answer.** Halfway between two transports there are two places that know about credentials, which is precisely the failure the hard rule bans — and the answer is not "finish the migration first", because the half-migrated state is where the app lives for weeks. Three rules make it survivable:

1. **The session module stays singular; only its *source* becomes a branch.** One `session.get()`, one refresh path, one logout fan-out. Inside it, one branch decides whether this request's credential comes from the cookie or the bearer store. Two session modules — one per transport — is two logouts, and one of them will be forgotten.
2. **Refresh belongs to whichever side holds the *refresh* credential, and only one side may.** If the BFF holds it, the SPA never refreshes: it retries once on 401 and lets the BFF do the work. Both sides refreshing against a rotating refresh token is the § 401 stampede with two participants who cannot see each other, and it produces the same "random logouts" symptom with no concurrency in the app to explain it.
3. **Logout fans out over both transports for the whole migration window.** Clearing the bearer store while the cookie survives leaves a session that the next request silently re-authenticates. Keep both teardowns until the old transport is deleted, and delete them in the same change that deletes it — a logout that clears a transport nobody uses is harmless; the reverse is a shared-device leak.

## Where the token lives (the trade, not a verdict)

| Option | What it buys | What it costs |
|---|---|---|
| **httpOnly cookie** | Script cannot read it, so an XSS payload cannot exfiltrate it. Readable by the server, so SSR sees the session on the first request. | CSRF surface — every state-changing request needs `SameSite` plus (for cross-site setups) a token or origin check. Cross-domain APIs need CORS credentials. |
| **In-memory (JS variable)** | Nothing on disk: a stolen device or a leaked `localStorage` dump yields nothing. Smallest XSS window. | Gone on refresh/new tab — you need a refresh cookie to re-establish, and you accept a flash of "logging in" on every reload. |
| **`localStorage` / `sessionStorage`** | Trivially readable everywhere, survives reload, works with any API host. | **Any** XSS reads it — including one in a dependency you did not write. It is not readable by the server, so SSR cannot personalise the first paint. |

The decision belongs in an ADR with the threat model written down. What is NOT negotiable: **whatever you choose, exactly one module touches it**, and a session read that bypasses that module is a finding (Detector 1).

## Silent refresh and the 401 stampede

Six components mount, six requests fire, the access token has just expired, six 401s come back. Without a single-flight gate, that is six refresh calls — which, against a backend that rotates the refresh token on use, means five of them present an already-rotated token, get rejected, and log the user out **in the middle of a working session**. The bug reads as "random logouts" and reproduces only under concurrency.

```ts
// ONE refresh in flight; everyone else awaits the same promise, then retries once.
let inFlight: Promise<void> | null = null;

async function refreshOnce() {
  inFlight ??= api.refresh().finally(() => { inFlight = null; });
  return inFlight;
}

onResponseError(async (error, request) => {
  if (error.status !== 401 || request.retried) throw error;   // retry exactly once
  await refreshOnce();                                         // queue behind the single refresh
  return retry({ ...request, retried: true });
});
```

Three rules the snippet encodes: the promise is cleared in `finally` (a rejected refresh must not poison every later request); the retry flag is per-request (no infinite 401 loop); and a **failed** refresh runs the same teardown as an explicit logout — not a silent swallow that leaves the UI in a half-authenticated state.

## Logout invalidates everything, not just the token

On a shared device the next user must not see the previous user's data — and a cache that outlives the session shows exactly that. Logout is a fan-out:

1. Destroy the credential (clear the in-memory token; call the server endpoint that invalidates the cookie/session server-side — clearing the client copy alone leaves the session valid).
2. **Cancel in-flight requests** (abort the controllers) so a response that arrives after logout cannot write the previous user's data into a fresh cache.
3. **Clear the query/server-state cache entirely** — not "invalidate", *clear*. Invalidation refetches, which is the opposite of what you want.
4. Reset client stores holding user-scoped state; keep only genuinely global UI state (theme, locale).
5. Close realtime connections (`realtime-client.md` owns the socket; this pattern owns the trigger).
6. Broadcast to other tabs (below).
7. Navigate to the public route **after** the above, so no protected view re-renders with a half-cleared store.

## Cross-tab session sync

Two tabs, one session. Tab A logs out (or is logged out by a failed refresh) and tab B keeps showing a dashboard it can no longer load data for — every request 401s and the user sees an app that appears broken rather than logged out. The same applies in reverse: tab A logs in as someone else and tab B is now displaying the wrong person's data.

Broadcast the transition and have every tab react to it: `BroadcastChannel('auth')` where available, the `storage` event as the fallback (it fires in *other* tabs only, which is exactly the semantics you want). Broadcast the **event** (`logged-out`, `switched-user`), never the token itself.

## Route guard vs render guard (the flash of protected content)

A render guard (`{user && <Dashboard/>}`) decides *inside* the view: the route already mounted, the layout already painted, and any effect that fires on mount has already run — sometimes including a fetch that leaks the shape of protected data into the network tab. A route guard decides *before* the view exists.

Use the router's guard as the gate, and render a **determinate** third state while the session resolves — not the protected view, not the login page: `unknown | authenticated | anonymous`. Collapsing `unknown` into `anonymous` is what produces the login-flash on every reload; collapsing it into `authenticated` is what produces the protected-content flash. On a server-rendered route, resolve the session on the server so the first HTML is already the right one — and keep the resolved value out of render-time browser reads (`ssr-safety.md`).

## Accessible authentication (WCAG 2.2 SC 3.3.8, AA)

The login form is a conformance surface, not just a form:

- **Paste MUST work** in password and one-time-code fields. Blocking paste breaks password managers, which is the mechanism most users rely on to have a strong password at all.
- **Do not block password managers** — real `autocomplete` values (`current-password`, `new-password`, `one-time-code`, `username`), no `autocomplete="off"` on credential fields, no scripted field-splitting that managers cannot fill.
- **No cognitive-function test** as the only path: no "solve this puzzle", no transcribe-from-memory, no unassisted-recall step without an alternative mechanism.
- Errors follow `forms.md` — `aria-describedby`, `role="alert"`, focus moved to the first invalid field. A login error announced to nobody is a lockout for a screen-reader user.

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix expressed in the project's own session module.

**1. Session read directly from web storage, outside the canonical helper.**
```ts
// BAD - every component that does this is a second owner of the session
const token = localStorage.getItem('access_token');
// GOOD - one owner; components ask it, never the browser
const token = session.accessToken();
```
grep: `rg -n "(localStorage|sessionStorage)\.(get|set|remove)Item\(\s*['\"\`][^'\"\`]*(token|jwt|auth|session)"` — every hit outside the session module is a finding. (This is the forward-looking home for the V1 anti-pattern `migration-frontend.md` already catalogues.)

**2. Refresh with no single-flight gate.**
```ts
// BAD - each 401 starts its own refresh; with rotating refresh tokens, most of them lose
if (res.status === 401) { await api.refresh(); return retry(req); }
// GOOD - one refresh, everyone awaits it (see the snippet above)
if (res.status === 401 && !req.retried) { await refreshOnce(); return retry({ ...req, retried: true }); }
```
grep: find the refresh call sites with `rg -n "refresh(Token|Session)?\(|/auth/refresh"`, then check for a module-level in-flight holder: `rg -n 'let\s+(refreshing|refreshPromise|inFlight|pendingRefresh)'`. A refresh call with no holder anywhere in that module is the stampede.

**3. Logout that clears the token and nothing else.**
```ts
// BAD - next user on this device sees the previous user's cached lists
function logout() { session.clear(); router.push('/login'); }
// GOOD - credential, in-flight, cache, stores, sockets, other tabs, THEN navigate
function logout() { session.clear(); abortAll(); queryClient.clear(); resetUserStores(); socket.close(); authChannel.postMessage('logged-out'); router.push('/login'); }
```
grep: `rg -nU 'function logout[A-Za-z]*\([^)]*\)\s*\{[^}]*\}'` (and the `logout:`/`signOut` variants your codebase uses), then read each body against the seven-step fan-out above. The regex lists the bodies; a human confirms the contents — do not claim it matched what it cannot see.

**4. No cross-tab session sync.**
```ts
// GOOD - other tabs learn about the transition; the event travels, the token never does
const authChannel = new BroadcastChannel('auth');
authChannel.onmessage = (e) => { if (e.data === 'logged-out') session.hardReset(); };
```
grep: `rg -n "BroadcastChannel|addEventListener\(['\"]storage"` — zero hits in an app that keeps any session state in the browser is the finding.

**5. Protected content behind a render guard only.**
```
BAD:  the route mounts, the layout paints, then {user ? <Dashboard/> : <Redirect/>} decides
GOOD: the router guard resolves the session BEFORE the route mounts; while it is `unknown`,
      render the determinate loading state - neither the dashboard nor the login form
```
grep: list the router's guard registrations (`beforeEach` / `canActivate` / route middleware / `+layout.server` load) and diff them against the protected route table. A protected route with no guard entry is a finding even when the view happens to hide its contents.

**6. Credential field that blocks paste or the password manager (SC 3.3.8).**
```
BAD:  <input type="password" onPaste={(e) => e.preventDefault()} />
GOOD: <input type="password" autocomplete="current-password" />
```
grep: `rg -nUP 'type="password"(?:(?!/>)[\s\S]){0,200}?onPaste'` for the paste block, and `rg -nUP 'type="password"(?:(?!autocomplete)[\s\S]){0,160}?/>'` for the missing `autocomplete`. Both need PCRE2 (`-P`); without it, list `type="password"` hits and read each element. Also flag `autocomplete="off"` on any credential field.

**7. Credential in a URL, a log line, or an error report.**
```
BAD:  router.push(`/reset?token=${token}`)   // lands in history, referrers, and server logs
GOOD: a single-use token exchanged for a session server-side, never re-rendered into a link
```
grep: `rg -n '[?&](token|access_token|id_token|jwt)='` plus `rg -n 'console\.(log|info|debug)\(.*(token|session)'`. A token in a URL is also a token in the analytics payload and the error-tracker breadcrumb — check the tracker's scrubbing config before calling it clean.

## Closure verbs

- `centralize-session` — route a stray storage read through the one session module and cite the new call site.
- `single-flight-refresh` — add the shared in-flight promise + the once-only retry flag.
- `complete-logout` — extend teardown to the full fan-out (in-flight, cache, stores, sockets, tabs) and name each one closed.
- `sync-tabs` — add the broadcast + the listener; the event travels, never the credential.
- `guard-at-route` — move the decision from render into the router, with the determinate `unknown` state.
- `unblock-credential-field` — remove the paste block / restore real `autocomplete` values (SC 3.3.8).
- `halt-handoff` — token lifetime, rotation policy, or revocation semantics handed to the backend pack by name; socket re-auth handed to `realtime-client.md`; harness session handed to `visual-check`.

## Related

- `data-fetching.md` — the 401 to refresh to retry loop runs *through* its client and interacts with its cancellation rule; logout's cache clear is a write into the cache it owns.
- `realtime-client.md` — a socket authenticated at handshake must re-authenticate after a refresh and close on logout; that pattern owns the connection, this one owns the session transition that triggers it.
- `forms.md` — the login form's label / `aria-describedby` / error-announcement contract, and the `autocomplete` detector shared with SC 1.3.5.
- `ssr-safety.md` — on a server-rendered route the session is a per-request value: resolve it with the SSR-safe accessor, never from a render-time browser read.
- `error-boundaries.md` — a failed refresh is an expected error with a defined destination (logout + login route), not a boundary crash.
- `rules/migration-frontend.md` — its V1 anti-pattern "auth/session read directly from `localStorage` outside the canonical token-storage helper" is Detector 1 seen from the migration side.
- `visual-check` (skill) — owns the **test harness's** authenticated session (`tests/.auth/user.json`); a different session, deliberately kept separate from the application's.
- Backend pack (when co-installed): token issuance, rotation, revocation, and the refresh endpoint's replay defence. This pattern consumes that contract and states it; it does not design it.
