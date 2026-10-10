---
name: client-data-scan
description: "Client data-flow bugs: waterfalls, request races, stale cache after writes, no rollback, polling — request-proved."
kind: skill
pack: frontend
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: client-data-scan

## Premise

The browser half of the data path fails in ways no server log shows. A page fires twenty requests where one would do, or awaits three independent reads one after another. A typeahead paints the answer to the query before last. A create succeeds and the list still shows the old rows until a reload. An optimistic row stays on screen after the write failed. The second user on a shared laptop sees the first user's orders for a frame. A poll keeps running in a hidden tab. A mutation that charges money is retried by the client. Each request in these paths is fast and returns 200, so nothing alerts; the cost is wrong data on the screen or load nobody asked for.

This skill finds those defects in the source across the data libraries real apps use — TanStack Query (React, Vue, Svelte, Solid, Angular), SWR, RTK Query, Apollo, Next Server Actions, framework loaders, plain `fetch` in effects, RxJS — and proves each with a request-level oracle. It is the detector `@data-flow-auditor` (this pack) ranks and explains. Unlike the agent, it runs on a whole repo with no named page. It owns bundle-perf row **W1** (client N requests) as §1.

**Every finding cites the request site `<file:line>` + the route or component that issues it + the user intent that triggers it + the oracle that proved it (or the test that would settle it) + the fix in the project's own data layer.** A grep hit or a lint message is never a finding by itself. "No data-flow issues" is never printed: the output is the class-coverage block (§ Output).

**Detect statically, prove by request.** The proof is an oracle from [`proof-oracles.md`](../../../../snippets/proof-oracles.md) § Accessibility and UI states — **Request count** (V106), **Request order** (V110), **State matrix** (V105) — or one of the five request-level shapes spelled out in § Proof below, run against MSW 3 handlers in a component test or a production build in Playwright. A candidate read in code with no harness is **Unconfirmed**, carrying the test that would settle it. It is never dropped, and never promoted on reading alone ([`precedents/ui.md`](../../../../snippets/precedents/ui.md), the proof rule).

## The rule

A candidate is a finding when all four hold:

1. **A user intent reaches it.** A route, screen or interaction issues the request: a navigation, a keystroke, a click, a poll on a mounted view. A hook nobody imports, a story, a mock source or a dev-only script fails here.
2. **The bad interleaving or count really occurs.** The list really grows (N parents), responses can arrive out of order (the user can type faster than the API answers), the write can fail, two identities can share the browser. A domain constant (three currencies) or a strictly sequential flow fails here.
3. **Nothing already handles it.** No keyed cache that discards a stale response by key, no router loader that cancels the stale navigation, no global `MutationCache` that invalidates, no shared helper (`invalidate(qc)`), no batch endpoint already used (`precedents/ui.md` § 35–38 and § False positives below).
4. **The oracle fired.** The request log, the order, the cache contents or the rendered value is shown wrong on the unfixed code.

## Boundaries

- **The stale closure and the out-of-order response inside one effect** → code-quality `correctness-smell-scan` §3, when the code-quality pack is installed. **UI request races across renders** — a typeahead, a filter, a tab, pagination — are §3 here (a route-param race is `routing-scan` §8, this pack). A hit both skills see is reported once, by `<file:line>`, credited to both. Without code-quality, §3 here reports both.
- **Effect and update loops, missing cleanup** → `render-correctness-scan` §1 and §2 (this pack). §7 here owns only the network cost: a fetch reached on every render or identity change, and polling. Dedupe by `<file:line>`.
- **Missing loading, error, empty, forbidden or offline states, double submit** → `ui-state-scan` (ui-ux pack, when installed). Its §8 defers optimistic rollback mechanics to §5 here. Without ui-ux, state rows print `N/A (owner pack ui-ux not installed)`.
- **SSR data semantics** — Next `fetch` caching and `revalidate`, Nuxt `useAsyncData` key collisions, SvelteKit universal-load double fetch, Angular transfer cache — and **module-scope server state shared across requests** → `ssr-audit` (this pack).
- **Server-side N+1** behind a client call → database `n-plus-one-scan`; outbound per-element calls in a server → performance `request-path-scan` §3 (each when its pack is installed). §1 here owns the browser's request count only; name the server cause and route it.
- **A cache key missing the tenant or the acting user** is a cross-user leak. §6 here reports the client key as corroboration; the server scoping belongs to `@tenant-isolation-reviewer` (security pack, when installed). A client key fix is a mitigation, never the fix. Without the security pack, the row is reported here as **critical**, tagged `security-class (owner pack not installed)`.
- **Retries of money, stock or single-use writes** (§8) need the server idempotency key from `logic-race-scan` (security pack, when installed); §8 owns the client retry policy.
- **Over-fetch and entitlement, hydration mismatches** → `@data-flow-auditor` classes 4 and 5 (judgement, not detection) and `ssr-audit`.

## Adapt to the codebase — the data lanes

Read each library **with its version** from the lockfile and print the lanes you ran in the output header. Versions below were read from the npm registry on 2026-10-05.

| Lane | Libraries (version read 2026-10-05) | Lint lane | Built-in that is a precedent |
|---|---|---|---|
| **React / Next / React Router / Remix** | `@tanstack/react-query` 5.104.1, swr 2.5.1, `@reduxjs/toolkit` 2.13.0 (RTK Query), `@apollo/client` 4.3.1, urql; Next 16.3.8 Server Actions; react-router 8.4.0 data APIs | `@tanstack/eslint-plugin-query` 5.104.1 `flat/recommended` (8 rules) | keyed caches dedupe identical keys in flight and drop a stale response by key; router loaders cancel the superseded navigation |
| **Vue 3 / Nuxt 4** | `@tanstack/vue-query`, `@pinia/colada`, Pinia, Nuxt `useFetch` / `useAsyncData` + `refreshNuxtData` | same plugin for Vue Query | keyed `useFetch` with a reactive key |
| **Svelte 5 / SvelteKit 3** | `load` + `invalidate` / `invalidateAll`, `@tanstack/svelte-query` (`createQuery`, `createMutation`) | — (greps) | loaders are race-safe by navigation |
| **Angular 20–22** | `HttpClient` + RxJS, NgRx / SignalStore, `@tanstack/angular-query-experimental` (`injectQuery`, `injectMutation`) | rxjs-x 1.0.6 has `no-unsafe-switchmap` (opt-in) — it targets the **reverse** case, a `switchMap` that cancels writes | `switchMap` cancels the superseded request |
| **Solid / Qwik / plain fetch** | `createResource`, `routeLoader$`, hand-rolled `fetch` | none — greps only | — |

TanStack facts this skill relies on, read from the `@tanstack/query-core` 5.104.1 type declarations and `retryer.js` (2026-10-05): `refetchIntervalInBackground` defaults to `false`; mutation `retry` defaults to `0`; query `retry` defaults to 3 in the browser (`isServer() ? 0 : 3`); `onMutate(variables, context)` and `onError(error, variables, onMutateResult, context)`, where `context.client` is the `QueryClient` — the older 3-argument `onError(err, vars, ctx)` still works positionally for its first three arguments. Detectors key on these API names, never on a major number.

## Lint lane

Run in a scratch directory, never in the project, and never commit the config. The plugin's eight rules are `exhaustive-deps`, `stable-query-client`, `no-rest-destructuring`, `no-unstable-deps`, `infinite-query-property-order`, `no-void-query-fn`, `mutation-property-order` and `prefer-query-options`. **No rule checks a mutation with no invalidation or a missing `onError` rollback** — greps 4a and 5a cover those. Keep `exhaustive-deps` (→ §6), `no-unstable-deps` and `stable-query-client` (→ §7); the rest are advice. A lint lane that cannot install prints `blocked (<reason>)` for its rule column; the greps still run.

```bash
L="$(mktemp -d "${TMPDIR:-/tmp}/cd-lint.XXXXXX")" && (cd "$L" && echo '{"private":true}' > package.json && npm i --silent --no-audit --no-fund eslint@9 @tanstack/eslint-plugin-query@5.104.1 typescript-eslint >/dev/null)
cat > "$L/query.mjs" <<'EOF'
import pluginQuery from '@tanstack/eslint-plugin-query'; import tseslint from 'typescript-eslint';
export default [{ ignores: ['**/node_modules/**', '**/dist/**', '**/build/**', '**/.next/**', '**/*.{test,spec,stories,mock}.*', '**/{test,tests,__tests__,e2e,scripts}/**'] },
  ...pluginQuery.configs['flat/recommended'],
  { files: ['**/*.{ts,tsx,js,jsx}'], languageOptions: { parser: tseslint.parser, parserOptions: { ecmaFeatures: { jsx: true } } } }];
EOF
"$L/node_modules/.bin/eslint" --no-config-lookup -c "$L/query.mjs" -f json "${ROOTS[@]}" > "$L/query.json"
node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1]));for(const f of r)for(const m of f.messages)if(/exhaustive-deps|no-unstable-deps|stable-query-client/.test(m.ruleId||""))console.log(f.filePath+":"+m.line+"  "+m.ruleId+"  "+m.message)' "$L/query.json"
```

**Measured** (2026-10-05, a read-only React 19 + Vite + TanStack Query 5.102 + React Router 7 application, 2,696 files linted in 10 s; the project's own config does not load the plugin): 12 `exhaustive-deps` messages, nothing else kept. Six were read: five are key factories that take the whole params object or a value derived from the key's own input (refuted on read, § False positives), one is a key on an account id while the fetch also reads a merchant id (Unconfirmed until the id's uniqueness is read). 32 further messages were unused-`eslint-disable` notices from the project's own comments and are dropped.

## Pre-flight greps

Run as **one** script from the repo root. Grep **N** feeds detector **§N**; grep 0 is context. Every `rg` names its path (`"${ROOTS[@]}"`); given no path, rg reads stdin under an agent's shell and reports a silent zero. Any rg exit 2 is a failed grep, never zero hits. File-level greps use `--files-without-match` — never `rg -L`, which is `--follow`. `NET` matches a network call through `fetch`, axios, ky or a client object named `api` / `http` / `client` / `request`; add the project's own client name from `_extracted-idioms.md`.

```bash
ROOTS=( $(rg -l --pcre2 '"(?:react|vue|svelte|@angular/core|solid-js|preact|next|nuxt)"\s*:' -g '**/package.json' -g '!**/node_modules/**' . | xargs -n1 dirname | sort -u) ); [ ${#ROOTS[@]} -eq 0 ] && ROOTS=(.)
X=(-g '!**/node_modules/**' -g '!**/{dist,build,out,.next,.nuxt,.output,.svelte-kit,.angular,coverage,storybook-static}/**'
   -g '!**/{test,tests,__tests__,__mocks__,mocks,e2e,fixtures,__fixtures__,playwright,cypress,msw,scripts}/**' -g '!**/*.{test,spec,stories,story,e2e,mock,mocks}.*'
   -g '!**/{locales,locale,i18n,translations,docs,generated,__generated__}/**' -g '!**/*.{gen,generated}.*' -g '!**/*.min.*')
J=(-g '*.{js,jsx,ts,tsx,mjs,vue,svelte}'); T=(-g '*.{jsx,tsx,vue,svelte}')
NC=(rg -v --pcre2 '^[^:]+:\d+:\s*(?://|/\*|\*(?:\s|/|$)|\{/\*|<!--)')   # drops comment-only lines
NET='(?:\bfetch|\$fetch|\baxios(?:\.\w+)?|\bky(?:\.\w+)?|\b(?:api|http|client|apiClient|request)\.(?:get|post|put|patch|delete|request|query))\s*[<(]'
# 0a libraries and versions; 0b the query client's global defaults (retry, MutationCache callbacks, gate 3 of § The rule).
rg -n --no-heading --pcre2 '"(?:@tanstack/(?:react|vue|svelte|solid|angular)-query(?:-experimental)?|@tanstack/eslint-plugin-query|swr|@reduxjs/toolkit|@apollo/client|urql|@pinia/colada|pinia|@ngrx/\w+|rxjs|ky|axios|axios-retry|msw|next|nuxt|@sveltejs/kit|react-router(?:-dom)?|zustand)"\s*:' -g '**/package.json' -g '!**/node_modules/**' "${ROOTS[@]}"
rg -n --pcre2 'new\s+(?:QueryClient|MutationCache|QueryCache)\s*\(|defaultOptions\s*:' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# 1a two consecutive awaited reads in a loader, page, component or hook (read: does the second use the first?);
# 1b fan-out — Promise.all over a .map, an awaited call per loop item (the body may hold balanced braces, e.g. a
#    destructured `const { data } = await …`), useQueries over a list; 1c a data-fetching component rendered inside .map.
rg -n -U --pcre2 '^[ \t]*(?:const|let|var)\s+[^=\n]+=\s*await\s+[\w.$]+\s*[<(][^\n]*\n(?:[ \t]*(?://[^\n]*)?\n){0,2}[ \t]*(?:const|let|var)\s+[^=\n]+=\s*await\s+[\w.$]+\s*[<(]' -g '**/{routes,pages,app,views,screens,features,components,hooks,composables}/**/*.{ts,tsx,js,jsx,vue,svelte}' "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n -U --pcre2 'Promise\.all(?:Settled)?\(\s*\w+(?:\??\.\w+)*\.map\(\s*(?:async\s*)?\(?[\w{}\s,]*\)?\s*=>\s*(?:await\s+)?[\w.$]+\(|for\s*(?:await\s*)?\(\s*(?:const|let)\s+(?:\w+|\{[^}]*\}|\[[^\]]*\])\s+of\s+[^)]+\)\s*\{(?:[^{}]|\{[^{}]*\}){0,200}?\bawait\s+'"$NET"'|\buseQueries\(\s*\{\s*queries\s*:\s*\w+(?:\??\.\w+)*\.map\(' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
Q=$(rg -l --pcre2 '\buse(?:Suspense)?Query\(|\buseSWR\(|\buseFetch\(|\bcreateQuery\(' "${T[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -r rg -o --no-filename --pcre2 'export\s+(?:default\s+)?(?:function|const)\s+([A-Z]\w+)' -r '$1' | sort -u | paste -sd'|' -)
[ -n "$Q" ] && rg -n -U --pcre2 '\.map\(\s*\(?[^)]*\)?\s*=>\s*\(?\s*<(?:'"$Q"')\b' "${T[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# 2a a network call written in a component file, outside a queryFn / mutationFn / fetcher — on its line, or on any
#    enclosing (less-indented) line above it, so a multi-line `queryFn: async () => {` body is dropped too;
# 9a a store that fetches and keeps its own loading flag (S-10).
rg -n --pcre2 "$NET" "${T[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}" | rg -v --pcre2 'queryFn|mutationFn|fetcher' | while IFS= read -r h; do f=${h%%:*}; r=${h#*:}
  awk -v n="${r%%:*}" 'NR<n{L[NR]=$0;next} {d=match($0,/[^ \t]/); for(i=n-1;i>0;i--){ if(L[i]!~/[^ \t]/) continue; j=match(L[i],/[^ \t]/); if(j<d){ if(L[i]~/(queryFn|mutationFn|fetcher)[ \t]*[:=(]/) exit 1; d=j; if(j==1) exit 0 } } exit 0}' "$f" && echo "$h"; done
rg -l --pcre2 'createAsyncThunk|createSlice|\bcreate\(\s*\(set|defineStore\(|createStore\(|signalStore\(|createReducer\(' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -r rg -l --pcre2 "$NET" | xargs -r rg -l --pcre2 '\b(?:loading|isLoading|status|error)\s*[:=]'
# 3a files where an effect / watcher fetches and writes state with no cancellation and no keyed cache; 3b RxJS typeahead flattened with mergeMap / concatMap.
rg -l --pcre2 '\buseEffect\(|\bwatch(?:Effect)?\(|\$effect\(|\bonMount\(' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -r rg -l --pcre2 "$NET" | xargs -r rg -l --pcre2 '\bset(?!Interval|Timeout|Immediate)[A-Z]\w*\b|\.value\s*=|\bthis\.\w+\s*=(?!=)' | xargs -r rg --files-without-match --pcre2 'AbortController|\bsignal\b|\bignore\b|cancel(?:l)?ed|isMounted|\bactive\s*=\s*false|onCleanup|onWatcherCleanup|switchMap|useQuery|useSWR|createQuery'
rg -n -U --pcre2 '(?:valueChanges|fromEvent\([^)]*\)|\w+\$)\s*\.pipe\([^;]{0,300}?\b(?:mergeMap|flatMap|concatMap)\(' -g '*.ts' "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# 4a mutation files that touch no cache; 4b RTK Query mutations (read invalidatesTags against providesTags); 4c Server Action files that never revalidate.
rg -l --pcre2 '\b(?:useMutation|createMutation|injectMutation)\s*[<(]' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -r rg --files-without-match --pcre2 'invalidateQueries|setQueryData|setQueriesData|refetchQueries|resetQueries|removeQueries|\brefetch\(|revalidate|\binvalidate\w*\(|cache\.(?:modify|evict|writeQuery|updateQuery)|update\s*\(\s*cache|awaitRefetchQueries'
rg -n --pcre2 '\b\w+\s*:\s*(?:builder|build)\.mutation\s*[<(]' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -l --pcre2 "^['\"]use server['\"]" "${J[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -r rg --files-without-match --pcre2 'revalidatePath|revalidateTag|updateTag|\brefresh\(|\bredirect\('
# 5a onMutate with no onError in the file; 5b RTK updateQueryData never undone; 5c SWR rollback switched off.
rg -l --pcre2 '\bonMutate\s*[:(]' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -r rg --files-without-match --pcre2 '\bonError\s*[:(]'
rg -l --pcre2 '\bupdateQueryData\(' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -r rg --files-without-match --pcre2 '\.undo\(\)'
rg -n --pcre2 'rollbackOnError\s*:\s*false' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# 6a a literal one-word key whose fetcher takes an argument (`(await …)` is not an argument); 6b SWR string key with a closure argument; 6c sign-out sites, then cache clears; 6d persisted caches.
rg -n -U --pcre2 'queryKey\s*:\s*\[\s*["\x27`][^"\x27`$]+["\x27`]\s*\]\s*,\s*queryFn\s*:\s*(?:async\s*)?\(\s*\)\s*=>\s*[^\n]*\(\s*(?!(?:await|async)\b)[a-z]\w*' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --pcre2 "useSWR(?:Immutable|Infinite)?\(\s*['\"][^'\"\$]+['\"]\s*,\s*(?:async\s*)?\(\)\s*=>\s*\w+\(\s*[a-z]" "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --pcre2 '\b(?:logout|logOut|signOut|signout)\s*(?:=\s*(?:async\s*)?\(|\(|:\s*(?:async\s*)?\()' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --pcre2 '(?:queryClient|qc|client)\.(?:clear|removeQueries|resetQueries)\(|\.(?:clearStore|resetStore)\(|cache\.reset\(|\bmutate\(\s*\(\)\s*=>\s*true' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --pcre2 'persistQueryClient|PersistQueryClientProvider|create(?:Sync|Async)StoragePersister|persister\s*:' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# 7a polling sites and background opt-ins; 7b setInterval that fetches in a file with no visibility check; 7c an object rebuilt each render feeding effect deps.
rg -n --pcre2 '\b(?:refetchInterval|refreshInterval|pollingInterval|pollInterval)\s*:|refetchIntervalInBackground\s*:\s*true|refreshWhenHidden\s*:\s*true' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -l -U --pcre2 'setInterval\(\s*(?:async\s*)?(?:\(\)\s*=>|function)[^;]{0,300}?(?:'"$NET"'|refetch\(|invalidate\w*\()' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -r rg --files-without-match --pcre2 'visibilitychange|visibilityState|document\.hidden|focusManager|useDocumentVisibility'
rg -n -U --pcre2 'const\s+(\w+)\s*=\s*\{[^;]{0,400}?\};?[\s\S]{0,800}?useEffect\([\s\S]{0,600}?\[\s*[^\]]*\b\1\b[^\]]*\]\s*\)' "${T[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# 8a mutations retried; 8b query / client retry config (read for 4xx); 8c a hand-rolled retry wrapper around a write.
rg -n -U --pcre2 'mutations\s*:\s*\{[^}]{0,200}?\bretry\s*:(?!\s*(?:0|false)\b)|\b(?:useMutation|createMutation|injectMutation)\s*[<(][^;]{0,600}?\bretry\s*:(?!\s*(?:0|false)\b)' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --pcre2 '\bretry\s*:\s*(?:true|[1-9]\d*)\b|\bretry\s*:\s*\{[^}]*methods\s*:[^}]*\bpost\b|axiosRetry\(|retryCondition\s*:' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n -U --pcre2 '\b(?:withRetry|retry\w*|pRetry|backoff\w*)\(\s*(?:async\s*)?\(\)\s*=>[^;]{0,400}?\bmethod\s*:\s*["\x27](?:POST|PATCH|DELETE|post|patch|delete)\b' "${J[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
```

A finding is a hit **plus** a read of the call site **plus** the user intent that reaches it **plus** the oracle. Three blind spots are structural:

- **Wrappers hide the library.** A project hook (`useApiMutation`, a `source()` helper, a query-options factory) may add invalidation, `signal` or retry for every caller. Read each wrapper once; a defect in it is one finding with N call sites, and a correct one refutes them all.
- **The key factory hides the key.** `keys.list(params)` can carry every input; lint and grep 6a see only the call. Open the factory before reporting §6.
- **Counts exist only at runtime.** A component that looks N+1 may be deduplicated by the query layer, and one that looks fine may fan out through a child (`@data-flow-auditor` halt 6). §1 and §7 are candidates until the request log runs.

**Measured** (2026-10-05, the script above, under 1 s per tree):

| Tree | Hits that matter | Verdict |
|---|---|---|
| research fixtures `B-rg/fx` (positives / decoys) | 3a 1 · 4a 3 · 4c 1 · 5a 1 · 5b 1 · 6b 1 | every seeded positive caught (fetch race, mutation without invalidation + the two double-submit files that also lack it, Server Action without revalidate, `onMutate` without `onError`, RTK patch never undone, SWR key without its param); 0 hits on the six decoys (AbortController, `invalidateQueries`, rollback with `context.client`, `.undo()` in `catch`, array and template-literal SWR keys, `revalidatePath`) |
| scratch fixtures for 1a–1c, 3b, 6a, 6c, 7a–7c, 8a–8c, 9a (one positive + one decoy each) | each positive 1 | 0 decoy hits after two fixes: `retry\s*:\s*(?!0)` let `\s*` backtrack past `retry: 0` (now `retry\s*:(?!\s*(?:0\|false)\b)`), and 3a counted `setInterval(` as a state write |
| `benchmarks/fixtures/web-dashboard` | 2a 1 · 3a 1 | WEB-IMPORT-01 (raw `fetch` in `OrderDetailPanel.tsx:16`) caught; the same effect is a prop-keyed race candidate (3a) |
| `quality-mix/web` | 2a 1 · 8c 1 | `BillingPage.tsx:13–15` wraps a credit **POST** in `withRetry` — a §8 candidate the first version (8a/8b only) missed |
| `review-decoys/change/web` | 3a 1 | `useRefund.ts`: an effect fetch with `[]` deps and no abort (candidate; the stale-prop half is code-quality's) |
| real React 19 + TanStack Query + React Router app, 2,696 source files | 0b 6 · 1a 1 · 1b 9 · 1c 0 · 2a 0 · 3a 0 · 4a 11 files · 6c 12 sign-out sites + 5 clears · 7a 20 · 8a–8c 0 | 1a: a GET whose result feeds the next POST — dependent, refuted. 1b: four candidates — two exports that fetch each selected order by id, a serial `for … of` with one awaited POST per task, one write per card — and five Hardening: chunked `Promise.all` / `useQueries` over pages of ids, and one PUT per currency (a domain constant). 4a: 5 sign-in / registration flows and 2 export jobs change no cached list (refuted on read), 1 hit is a doc comment, 3 remain to read. 6c: sign-out clears the query cache (`queryClient.clear()`), so the logout half is refuted. 7a: 20 `refetchInterval` sites, none opting into background polling (TanStack default `false`). 0b shows query retry as a function on status — the §8 decoy |

Before the fixes, 1a matched 226 lines on the real app (one-off Playwright scripts under `scripts/` — now excluded — and positive globs OR-ed with the extension glob, which nullified the directory restriction). Small fixtures prove the greps parse and catch seeded rows; precision at scale comes from the real-app row.

## The 3,000-hit path

1. **Intersect** with the route table: a hook no route reaches is dismissed with one read. Mocks, stories and dev scripts are already excluded.
2. **Group** by (data wrapper or key factory, pattern). A wrapper or factory with the defect is one group however many call sites it has; fixing it closes them.
3. **Rank** by route traffic (RUM or analytics when present), else list, detail, checkout-class and dashboard routes; then by data sensitivity (§6 tenant keys first).
4. **Read the top 30 groups fully.**
5. **Prefer the runtime bulk oracle at scale.** One Playwright pass over the route matrix with a request log (count per route at two data sizes, out-of-order delays, a write-then-read per list) confirms or refutes whole groups.
6. **Ledger the rest** `Live, unreviewed (k groups / n hits)` with the command that continues them. Never mark them `checked`.

## Scans for

Severity is the user-visible consequence on a reachable route. Raise one step on money, permissions or another identity's data; drop one step when the view is an internal tool with a single operator and the data is refreshed by design.

| § | Class | Research id | Default |
|---|---|---|---|
| 1 | Request waterfall; N requests where one would do (bundle-perf **W1**) | CD-01, U-12 | medium; high when N is unbounded or on the landing / list route |
| 2 | Fetch in a component that bypasses the API client and the cache | CD-02 (WEB-3) | medium (no auth, no base URL, no dedupe); low when the client is equivalent |
| 3 | Out-of-order responses; no cancellation (UI races across renders) | CD-03, S-05 | medium; high on financial or permission lookups |
| 4 | Write with no invalidation or cache update — stale list after a write; stale view after back/forward | CD-04, S-11, R-08 | medium; high when the stale view drives the next write |
| 5 | Optimistic update with no rollback | CD-05, U-02 | high on money or permissions; else medium |
| 6 | Key missing an input (another entity's data shown); cache not cleared on sign-out | CD-06, S-11 | **critical** when the missing input is the tenant or the user; else medium |
| 7 | Polling with no visibility pause or backoff; a refetch on every render | CD-07, S-03 (network half) | medium; high when it loops |
| 8 | Retry policy wrong: a non-idempotent write retried; 4xx retried | CD-08, U-08 | high on money / stock / single-use writes; low for a 4xx retry |
| 9 | Server state copied into a global client store | S-10 | low (informational) unless it causes §4 or a stale view |

### 1. Request waterfall; N requests where one would do

```
BAD:   const user = await api.get(`/users/${id}`); const orders = await api.get('/orders');   · ids.map((id) => <PriceCell id={id} />)  (each cell useQuery)
GOOD:  const [user, orders] = await Promise.all([…]) · one batch read (`/prices?ids=…`) or the datum embedded in the parent response · fetch on reveal
```
**Read the code:** Does the second read use the first one's result (then it is a dependency, not a waterfall)? Is the fan-out bounded and chunked (pages of ids at the API's max page size — Hardening)? Does the query layer dedupe the per-row key? Which fix applies — embed in the parent, a batch endpoint, or fetch on reveal (`@data-flow-auditor` class 3)? A server-side cause is routed (§ Boundaries). **Finding when** the request count for one navigation grows with N, or independent reads start only after each other finishes. **Proof:** *Request timeline* (§ Proof) at N = 2 and N = 20.

### 2. Fetch in a component that bypasses the API client and the cache

**Read the code:** Does the raw call skip the client's auth header, base URL, error mapping or the query cache that sibling views use? Is the component the only caller (then it is a missing abstraction, low) or does it duplicate a cached read (then the network log shows the same URL twice)? §9 rides here: a slice or store with its own `loading` flag and a thunk that fetches holds server state outside the cache — informational unless it produces §4 or a stale view. **Finding when** the call loses a guarantee the project's client gives (auth, errors, dedupe). **Proof:** static fact for the bypass (the two-ended trace: the call and the client it skips); *Request count* (V106) for the duplicate read.

### 3. Out-of-order responses; no cancellation

```
BAD:   useEffect(() => { fetch(`/api/search?q=${q}`).then(r => r.json()).then(setResults) }, [q])   · valueChanges.pipe(mergeMap(q => http.get(…)))
GOOD:  const ac = new AbortController(); fetch(url, { signal: ac.signal })…; return () => ac.abort()   · switchMap   · a keyed useQuery({ queryKey: ['search', q] })
```
**Read the code:** Can the input change while a response is in flight (typing, a filter, a tab, pagination)? Does a keyed cache or a router loader already discard the stale response? Vue: `onWatcherCleanup` / the `onCleanup` argument; Svelte 5: the `$effect` teardown. **Finding when** a slower earlier response can overwrite a later one on screen. **Proof:** *Request order* (V110): the first request delayed past the second; the UI must show the second's data and never flash the first's.

### 4. Write with no invalidation or cache update

```
BAD:   useMutation({ mutationFn: createTodo })                      · 'use server' export async function create(fd) { await db.insert(fd) }
GOOD:  onSuccess / onSettled: invalidateQueries({ queryKey: todoKeys.all }) or setQueryData · revalidatePath('/todos') / updateTag(…)
```
**Read the code:** Which keys does the write change — the list under every filter, the detail, counters, an infinite query's pages? Does a project helper or a global `MutationCache` already invalidate? RTK Query: does every `invalidatesTags` type appear in some `providesTags` (grep 4b; read the api slice)? Apollo: does the type have an `id` / `keyFields` so the result normalizes, or does the mutation `refetchQueries` / `update` the cache? SWR: does the bound `mutate` key match the list's key (a `?page=1` suffix does not)? A write that changes no cached view (sign-in, an export job, a message send) is not a candidate. **Finding when** a view that shows the written entity still shows the old value after the write, without a reload — or after back/forward (R-08). **Proof:** *Write-then-read* (§ Proof).

### 5. Optimistic update with no rollback

```
BAD:   onMutate: async (t) => { qc.setQueryData(['todos'], (old) => [...old, t]) }           (no onError)
GOOD:  onMutate: async (t, ctx) => { await ctx.client.cancelQueries(…); const previous = ctx.client.getQueryData(…); …; return { previous } }
       onError: (err, t, onMutateResult, ctx) => ctx.client.setQueryData(…, onMutateResult.previous) · onSettled: invalidate
```
**Read the code:** Does `onError` restore the snapshot `onMutate` returned? Is `cancelQueries` called before the write (an in-flight refetch otherwise overwrites it)? Does `onSettled` invalidate? RTK: is the `patchResult` from `updateQueryData` `.undo()`ne in the `catch`? Optimistic UI rendered from `variables` while pending, React `useOptimistic`, Apollo `optimisticResponse` and SWR `optimisticData` with the default rollback revert by construction (`precedents/ui.md` § 37). **Finding when** a failed write leaves the optimistic value on screen. **Proof:** *Failed optimistic write* (§ Proof), including two writes in flight.

### 6. Key missing an input; cache not cleared on sign-out

**Read the code:** List every input that changes the response — tenant, acting user, locale, each filter, the entity id — and diff it against the key's arguments; open the key factory. Does sign-out clear the cache (`queryClient.clear()`, Apollo `clearStore()`, SWR `mutate(() => true, undefined, { revalidate: false })`) and any persisted cache (grep 6d)? **Finding when** switching the entity, tenant or user can paint the previous one's data. A missing tenant or user input is **critical** and also a security row (§ Boundaries). **Proof:** *Identity switch* (§ Proof).

### 7. Polling with no visibility pause or backoff; a refetch on every render

**Read the code:** Does the poll stop in a hidden tab — TanStack `refetchIntervalInBackground` (default `false`), SWR `refreshWhenHidden` (default `false` [K: confirm against the installed version]), a hand-rolled `setInterval` with a `visibilitychange` check? Does it stop when the job finishes (`refetchInterval` as a function returning `false`)? Does a fetch sit behind effect deps that change identity every render (grep 7c), or a `QueryClient` created inside a component (`stable-query-client`)? The render loop itself is `render-correctness-scan` §1. **Finding when** requests keep flowing with no user input, or in a hidden tab with no declared need. **Proof:** *Idle request rate* (§ Proof).

### 8. Retry policy wrong

**Read the code:** Is a write that is not idempotent retried — a mutation `retry`, an `axios-retry` `retryCondition` that accepts POST, ky `retry.methods` including `post`, a `withRetry` wrapper around a POST? Does the server take an idempotency key (then the retry is safe)? Does the query retry policy retry 403 / 404 behind a spinner (TanStack's 3 browser retries apply to every error unless `retry` is a function on status — `precedents/ui.md` § 38)? **Finding when** one user intent can send a write twice, or a 4xx is retried before the user sees the state. **Proof:** *Request count* (V106): MSW answers 500 (write) or 400 / 403 (read) → exactly one request (or the declared count).

### 9. Server state copied into a global client store

**Read the code:** Does a Redux slice, Zustand / Pinia store or NgRx feature hold API data with its own `loading` / `error` flags and no staleness or refetch, while the project also uses a query cache? Report it when it causes a §4 stale view or a §6 leak; otherwise it is an architecture note (owner code-quality's architecture lanes, when installed). **Proof:** the §4 or §6 oracle for the symptom; none for the note.

## Proof

Each § names its oracle. Request count (V106), Request order (V110) and State matrix (V105) are in [`proof-oracles.md`](../../../../snippets/proof-oracles.md) § Accessibility and UI states. The five request-level shapes below are not in that file yet (integrator request); until they are, the test writer uses them as written here:

- **Request timeline** — record `page.on('request')` / `requestfinished` (url, start, end) for one navigation at N = 2 and N = 20 parents. Fails when the count grows with N, or an independent read starts after another ends.
- **Write-then-read** — a stateful MSW handler (POST appends to an in-memory array that GET returns) or a real backend; create, update, delete through the UI; the list **and** the detail show the change with no `page.reload()`, and still after `goBack()` / `goForward()`.
- **Failed optimistic write** — the write answers 500 after `delay(300)`; the optimistic value is visible, then the previous value returns and an error is announced; with two writes in flight the second survives the first's rollback.
- **Identity switch** — switch entity, tenant or user with the new response held; `expect.poll` sampling never sees the previous identity's rows; after sign-out the query cache and any persisted cache are empty.
- **Idle request rate** — fake timers plus an MSW counter; hide the tab (`focusManager.setFocused(false)`, or `document.visibilityState` stubbed to `'hidden'` + `visibilitychange`), advance 60 s: no polling request; visible with no input for 5 s: fewer than 2 requests after the initial load.

Every test runs on a production build or a component test with MSW 3 (`http`, `HttpResponse`, `delay` from `'msw'`; `graphql` now from `'msw/graphql'`), asserts the **one** behaviour the finding names, and **fails before the fix**. A test that passes on the unfixed code proves nothing: rebuild it until it fails. A fix is accepted when the oracle goes green, the class variants pass (V106 / V110 variant lists, plus: the list **and** the detail key, a paginated and an infinite key, two concurrent writes, an expired session), and the owning grep goes quiet on the line. Never accepted: raising `staleTime` or a TTL to hide a stale view, clearing the cache on sign-out as the fix for a key missing the tenant, `retry: false` on a read to hide a 4xx loop without rendering the state, deleting the test.

## Output

```
client-data-scan — lanes: react 19.2 + @tanstack/react-query 5.104 (lint: eslint-plugin-query 5.104.1, scratch eslint 9), ky 2.1, react-router 7.18; swr, rtk, apollo absent
Context: QueryClient src/app/query-client.ts — query retry is a function on status · MutationCache onError only (no global invalidation) · helper invalidate(qc)

Findings: 2 · Unconfirmed: 2

1. src/orders/ExportSelectedButton.tsx:41                         [report-with-fix]   medium
   §1 N requests (W1) — exporting the selection fetches each order by id:
   Promise.all(selected.map((o) => getOrder(o.id))). Route /orders → select 50 → Export.
   Proof: e2e/data/orders-export.spec.ts — Request timeline: 2 requests at 2 selected, 50 at 50.
   Fix: one read per page of ids through the list endpoint's ids filter (chunked at its max page size).

2. src/todos/useAddTodo.ts:12                                      [report-with-fix]   medium
   §4 create with no invalidation — useMutation({ mutationFn: createTodo }) touches no cache; /todos keeps the old
   list until reload. Proof: src/todos/useAddTodo.test.tsx — Write-then-read fails (row absent after create).
   Fix: onSettled: () => invalidate(qc, todoKeys.all), the project's helper.

3. src/billing/useRates.ts:18                                      [report-flagged]    critical
   §6 key ['rates', accountId] while the fetch also reads tenantId. Unproven link: whether accountId is unique across
   tenants. Settling test: Identity switch — tenant A → tenant B sharing an account id; B must never show A's rates.
   Server scoping: @tenant-isolation-reviewer (security pack).

4. src/tasks/api.ts:77                                             [report-flagged]    low
   §1 one awaited POST per task in a for…of. Unproven link: whether the API offers a bulk create.
   Settling test: Request timeline at 2 and 20 tasks.

Verification: 58 candidates → 2 findings · 2 unconfirmed · 9 hardening · 0 pre-existing · 45 refuted

Class coverage:
  §1 waterfall / N requests       checked (1 + 7 hits → 1 finding, 1 unconfirmed; 3 chunked fan-outs Hardening)
  §2 fetch bypassing the client   checked (0 hits)
  §3 out-of-order / cancellation  checked (0 files; every effect fetch goes through a keyed query)
  §4 write without invalidation   checked (11 files → 1 finding; 7 change no cached view; Live, unreviewed (2 files — continue with grep 4a))
  §5 optimistic rollback          checked (0 files)
  §6 key / sign-out               checked (12 lint → 1 unconfirmed, 5 refuted, 6 Live, unreviewed; sign-out clears the cache)
  §7 polling / refetch loop       checked (20 sites → 0 findings: none polls in the background)
  §8 retry policy                 checked (0 hits; query retry is a status function)
  §9 server state in a store      N/A (no client store holds API data)
```

`[report-with-fix]`: the call site, the intent that reaches it and a failing oracle are all present, and the fix is local to the project's data layer. `[report-flagged]`: one link is unproven (no harness, a key factory or wrapper not read, an unknown API capability), and the row names it and the settling test. The coverage block lists **all nine** classes on every run: `checked (k hits → m findings)` only when the grep (and lint lane, where one applies) ran on a present library; `N/A (<reason>)` only when the repo has no such surface (no mutations, no polling, no Server Actions); `blocked (<reason>)` when a grep failed or the lint lane could not install. A partial review reads `Live, unreviewed (k groups / n hits)`, never `checked`.

## False positives / precedents

The verifier reads [`precedents/ui.md`](../../../../snippets/precedents/ui.md) (UI states and client data § 35–41) and [`refute-before-report.md`](../../../../snippets/refute-before-report.md) § 4 and § 10 (the correctness column). The ones this skill meets most:

- **Keyed caches and router loaders are race-safe.** TanStack / SWR keyed queries discard a stale response by key; React Router, SvelteKit and Next server-component loaders drop the superseded navigation; Nuxt `useFetch` with a reactive key refetches per key. §3 does not apply to them. Identical keys in flight are deduplicated (`precedents/ui.md` § 38).
- **A key factory that takes the whole params object, or a key built from the same input the fetch derives its arguments from** (a day count → from / to dates), satisfies §6 even when `exhaustive-deps` flags it (5 of 6 measured lint hits).
- **A dependent second read is not a waterfall**; **a chunked fan-out** (pages of ids at the API's max page size) is the client twin of a chunked `IN (…)` — Hardening, not §1.
- **Writes that change no cached view** — sign-in, OTP, password reset, an export job, a message send — need no invalidation.
- **Optimistic UI that reverts by construction** (`precedents/ui.md` § 37). **Default retries** (§ 38). **Sign-out that calls `queryClient.clear()`** refutes the §6 sign-out half, never a §6 key defect.
- **Polling that pauses in the background by default** — TanStack `refetchIntervalInBackground` defaults to `false` (query-core 5.104.1 types, 2026-10-05). A poll that stops itself when the job completes is correct.

These local precedents are proposed for `precedents/ui.md` (integrator request); until they land, cite this section.

## When to run

- On any diff that adds or changes a query, mutation, cache key or key factory, a loader or Server Action, a polling interval, a retry setting, or an effect that fetches.
- On every whole-repo `/frontend-audit` (when the frontend audit command ships), reporting all nine classes; and as the evidence `@data-flow-auditor` ranks.
- When `/bundle-perf` (performance pack, when installed) reaches row W1 — §1 here is that row's detector.

## Halt conditions

- Do not report a high or critical row as confirmed until a verifier other than the run that found it has passed it through [`refute-before-report.md`](../../../../snippets/refute-before-report.md) § 10. Under an audit command that happens in its verification phase; run standalone, apply the protocol as a separate second pass, tag those rows `self-verified`, and list the rest as Unconfirmed, Hardening, Pre-existing or Refuted. Never drop them.
- Halt on any finding without the request site `<file:line>`, the user intent that reaches it, and the fix in the project's own data layer.
- Do not mark a finding `[report-with-fix]` without an oracle that failed (§2's bypass is the one static fact).
- Do not count requests in source and call it observed (§1, §7): label it Unconfirmed with the Request timeline or Idle request rate test.
- Do not report a §6 tenant or user key without opening the key's construction, and never close it with a client-only fix.
- Do not print "no data-flow issues" or "cache is correct". Print the coverage block; a class whose grep or lint lane did not run is `blocked`, never `checked`.
- Do not re-derive a class another skill owns (§ Boundaries). Cross-link it.

## Related

- `@data-flow-auditor` (this pack) — ranks and explains these findings on one named page; its class 3 is §1 here (W1), class 2 is §4, class 1 is §6.
- `routing-scan` (this pack) — route-param races (§8 there), stale data after back/forward routes to §4 here; `render-correctness-scan` and `ssr-audit` (this pack) — loops, cleanup, SSR data.
- `ui-state-scan` (ui-ux pack, when installed) — the states a request can answer; `correctness-smell-scan` (code-quality, when installed) — one-effect races.
- `/bundle-perf` (performance pack, when installed) — row W1 cites §1; `n-plus-one-scan` (database, when installed) — the server half.
- `@tenant-isolation-reviewer` and `logic-race-scan` (security pack, when installed) — server scoping for §6, idempotency for §8.
