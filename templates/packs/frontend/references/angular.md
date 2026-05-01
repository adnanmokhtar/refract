# Angular reference (17+, standalone + signals)

> **Framework**: Angular 17+ / 18 / 19 • TypeScript 5.4+ • RxJS 7.8+
> **Official docs**: https://angular.dev/
> **Version-specific gotchas**: Angular 17 made standalone components default + new control flow (`@if` / `@for` / `@switch`); 17.1 added typed forms inferred from values; 18 stabilized signals + zoneless change detection (preview); 19 promoted standalone components to required default; deferred views (`@defer`) for code-splitting; `inject()` function preferred over constructor DI in new code.
> **Substitution markers**: Replace `<name>` / `<feature>` with the project's actual feature names.

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
