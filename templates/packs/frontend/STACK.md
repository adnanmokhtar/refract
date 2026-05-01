# Frontend pack — stack assumption

This pack's commands, agents, skills, rules, ai-patterns, and examples assume:

- **Modern component framework** with reactive state + lifecycle hooks (Vue 3, React 18+, Svelte 4+, Angular 16+, Nuxt 3+, Next 13+, etc.)
- **TypeScript-first** typing
- **A shared-component / wrapper layer** that the project owns (the equivalent of `<BaseModal>`, `<FormField>`, etc., named in the project's `_extracted-idioms.md`)
- **Composable / hook abstraction** for reusable reactive logic
- **i18n with per-module locale files** (or framework equivalent)
- **A canonical HTTP client** with interceptor (auth + refresh)

## Inline examples in this pack

Wherever this pack's files show concrete syntax (component names, hook names, library calls), the syntax is **Vue 3 + PrimeVue + TypeScript** for illustration. Substitute your stack's equivalents:

| Vue 3 + PrimeVue (illustrated) | React + MUI/shadcn | Svelte + SvelteKit | Angular | Substitution source |
|---|---|---|---|---|
| `<script setup lang="ts">` | function components | `<script lang="ts">` | `@Component` class | language idiom |
| `ref()` / `reactive()` | `useState` | `let` + `$:` | properties | reactive primitive |
| `computed()` | `useMemo` | `$:` derived | `@Input` getter | derived state |
| `onMounted()` | `useEffect(() => {...}, [])` | `onMount()` | `ngOnInit()` | mount hook |
| `onActivated()` (KeepAlive) | route revisit handler | `+page.ts` `load` | route reuse strategy | reactivate hook |
| Composable (`useX()`) | Custom hook (`useX`) | Reusable function | Service / signal | reusable abstraction |
| `<BaseModal>` | `<AppModal>` | `<Modal>` | `<app-modal>` | shared modal wrapper |
| `<FormField label>` | `<Field name>` | `<FormField>` | `<app-form-field>` | shared field wrapper |
| `useLanguages().buildEmptyTranslations()` | `useI18n` helper | `i18n` store | `TranslateService` | dynamic-language helper |
| `apiClient` (axios + interceptors) | `apiClient` (fetch wrapper) | `apiClient` | `HttpClient` interceptor | canonical HTTP client |

## Where stack-specific names live

- The project's `_extracted-idioms.md` (per-project, populated by `/setup-project --refine`) — single source of truth for the actual wrapper / hook / util / class names this project uses.
- The project's `ai/migration/_v2-anchors.md` (per-project) — wrapper-vs-raw map, layering rules, lifecycle anchors.
- The validator script `scripts/validate-migration-artifacts.sh § check_v2_structure` — stack-conditional fingerprint set keyed by `PROJECT_KIND`.

If your project's frontend uses a stack with no current fingerprint set (e.g., Solid, Qwik, Lit), open a `frontend/by-stack/<stack>/` subdirectory + add a `PROJECT_KIND` case to the validator script. Until then, the pack's universal rules apply but the specific anti-pattern fingerprints are inactive.
