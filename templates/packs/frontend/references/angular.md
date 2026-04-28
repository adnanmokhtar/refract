# Angular reference (17+, standalone + signals)

## Structure

```
src/app/
├── core/                     # singletons — guards, interceptors, core services
├── shared/                   # reusable components, pipes, directives
├── features/
│   └── <name>/
│       ├── pages/            # route-level components
│       ├── components/       # feature-scoped components
│       ├── services/         # feature services (HTTP)
│       ├── store/            # signals / NgRx / signalStore
│       ├── models/           # DTOs, types
│       └── <name>.routes.ts
├── app.config.ts             # providers (HttpClient, Router, env)
└── app.routes.ts
```

## Rules (17+)

- Standalone components by default — no `NgModule` unless forced.
- Use `@Component({ standalone: true, imports: [...] })`.
- Use `@if` / `@for` / `@switch` — new control flow, NOT `*ngIf`/`*ngFor`.
- Signals for local reactive state: `signal()`, `computed()`, `effect()`.
- Use `inject()` function instead of constructor DI for concise DX — consistent with project convention.
- `ChangeDetectionStrategy.OnPush` for every component.

## Forms

- Reactive forms for anything beyond trivial.
- Typed forms (`FormGroup<MyFormShape>`).
- Validators composed — don't inline regex everywhere.

## HTTP

- `HttpClient` behind a feature service.
- Interceptors for auth + error + correlation id.
- `toSignal(obs)` to bridge observables into signal-based components.
- RxJS for streams; prefer `firstValueFrom` when you need a one-off promise.

## Routing

- Lazy-load every feature route: `loadChildren: () => import('./...')`.
- Route guards are functions (`canActivate: [authGuard]`), not classes (deprecated).

## Testing

- Jest (preferred) or Karma+Jasmine.
- Component tests via `@testing-library/angular` or `TestBed`.
- Test signal updates via `fixture.detectChanges()`.

## Anti-patterns

- `*ngIf` / `*ngFor` when `@if`/`@for` is available
- NgModule when standalone would do
- Subscription leaks — use `takeUntilDestroyed()` or `async` pipe
- Manual `subscribe()` without cleanup
- Business logic in templates
