---
name: forms
description: "Pattern: Forms"
kind: ai-pattern
pack: frontend
---

# Pattern: Forms

> **Hard rule:** Pick ONE form library per repo with schema-driven validation; map server `code` → field error programmatically (never string-match English); every input has a label, every error has `aria-describedby`, and the submit button reflects pending/disabled state. **Ad-hoc per-field state with hand-rolled validation**, or English-string error parsing, is forbidden in production forms. *Uncontrolled inputs managed by the form library are not the target of that rule and never were* — uncontrolled, ref-based registration is the performance thesis of the React library recommended below; forbidding it would forbid the recommendation.

**When to apply**
- Forms have non-trivial validation (cross-field, async uniqueness, multi-step).
- A form maps to a server DTO that returns `code` + `fieldErrors` from a typed error.
- Accessibility audits or screen-reader compatibility are in scope.

**When NOT to apply**
- A single search input or one-off filter — controlled `useState` is fine.
- A throwaway internal admin form behind auth with no a11y or i18n requirements.

**Halt conditions / mandatory cites**
- The form proposal MUST cite the validation schema at `<path:line>` AND the server DTO it mirrors.
- Field-error mapping MUST cite the server's `code` taxonomy file (the error-handling source of truth).
- A doc proposing manual per-field `useState` + manual validation in a non-trivial form is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "validation matches the API".
- If the project's chosen form library isn't extracted, halt before adding a new form.

Forms are where validation, UX, accessibility, and API contracts collide. Every project ends up needing the same primitives: schema-driven validation, field errors that map from server codes, submit-button behavior that doesn't trap users, and accessibility that survives a screen reader audit. Picking one library per repo and applying it consistently is more important than which library you pick.

## Context

Reach for a dedicated form library (and this discipline) when:
- Forms have non-trivial validation (cross-field, async uniqueness checks, multi-step).
- The same shape is validated on the frontend AND backend — schema sharing pays off.
- Accessibility is a real requirement, not a checkbox.
- You're seeing inconsistent UX across forms ("Why does the products form clear on error but the users form doesn't?").

For a single-input search field, native HTML + a state hook is enough. The pattern below applies to forms with > 3 fields or any validation beyond `required`.

## One library per repo, no mixing

| Stack | Recommended | Schema |
|---|---|---|
| Vue | `vee-validate` | `zod` or `yup` |
| React | `react-hook-form` | `zod` |
| Angular | Reactive Forms (built in) | typed `FormGroup` + custom validators |
| Svelte | `sveltekit-superforms` | `zod` |
| Solid | `@modular-forms/solid` | `valibot` |

Rules:
- One choice per repo. Mixing react-hook-form and Formik in the same React app means twice the patterns to maintain and inconsistent UX.
- Schema library matches: don't validate with yup in the form and zod in the API client — pick one schema lib and share.

## Schema-driven validation (single source of truth)

Define the schema once. The form, the API client, and the backend all consume it.

```ts
// shared/schemas/product.ts
import { z } from 'zod';

export const productSchema = z.object({
  name: z.string().min(1).max(120).trim(),
  sku: z.string().regex(/^[A-Z0-9-]+$/, 'SKU must be uppercase letters, numbers, dashes'),
  price: z.number().positive().multipleOf(0.01),
  stock: z.number().int().min(0),
  description: z.string().max(2000).optional(),
  categoryId: z.string().uuid(),
});

export type ProductInput = z.infer<typeof productSchema>;
```

Backend validates again — never trust client validation. Schema reuse on the backend (NestJS pipes, FastAPI Pydantic, Django serializers) is the goal but framework boundaries sometimes prevent literal sharing — re-deriving the schema in matching shape is acceptable. Diverging shapes is not.

## React Hook Form + zod (worked example)

```tsx
import { useForm, type FieldPath } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { productSchema, type ProductInput } from '@/shared/schemas/product';

export function ProductForm({ onSubmitted }: Props) {
  const {
    register, handleSubmit, setError, formState: { errors, isSubmitting },
  } = useForm<ProductInput>({
    resolver: zodResolver(productSchema),
    mode: 'onBlur',  // validate on blur, not every keystroke
    defaultValues: { stock: 0, price: 0 },
  });

  const { t } = useI18n();
  const router = useRouter();
  const productsApi = useProductsApi();

  const onSubmit = handleSubmit(async (values) => {
    try {
      await productsApi.create(values);
      toast.success(t('products.created'));
      router.push('/products');
      onSubmitted?.();
    } catch (err) {
      // Map server domain errors to form fields by stable code
      if (isDomainError(err) && err.code === 'DUPLICATE_SKU') {
        setError('sku', { type: 'server', message: t('products.errors.duplicate_sku') });
        return;
      }
      if (isDomainError(err) && err.code === 'VALIDATION_FAILED') {
        // `fe.field` is a PATH ('items[0].quantity'), never a key of the input type.
        // `as keyof ProductInput` compiles and then no-ops at runtime for every nested or
        // array-indexed field — the server rejects the sub-object and the user sees nothing.
        // `fe.meta` ({ min: 1, actual: 0 }) is the interpolation payload; without it the only
        // renderable string is the server's dev-facing `message`, which is not user copy.
        for (const fe of err.fieldErrors) {
          setError(fe.field as FieldPath<ProductInput>, {
            type: 'server',
            message: t(`products.errors.${fe.code.toLowerCase()}`, fe.meta ?? {}),
          });
        }
        return;
      }
      toast.error(t('errors.generic'));
    }
  });

  return (
    <form onSubmit={onSubmit} noValidate aria-busy={isSubmitting}>
      <div>
        <label htmlFor="name">{t('products.form.name_label')}</label>
        <input
          id="name"
          {...register('name')}
          aria-invalid={!!errors.name}
          aria-describedby={errors.name ? 'name-error' : undefined}
        />
        {errors.name && <p id="name-error" role="alert">{errors.name.message}</p>}
      </div>
      {/* repeat for sku, price, stock, description, categoryId */}
      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? t('common.saving') : t('common.save')}
      </button>
    </form>
  );
}
```

## UX rules

- **Validate on blur, not on every keystroke.** Per-keystroke is noisy and frustrating. Exception: password strength meters, username availability checks (those need debounced async validation).
- **Show errors inline under the field**, not in a summary at the top — except for forms with 10+ fields where a top-of-form summary helps screen readers and high-error scenarios.
- **Submit button: disabled while submitting, NOT while invalid.** Disabled-while-invalid means users can't see what's wrong without trying. Let them submit; show all errors at once; focus the first invalid field.
- **Preserve form state on submit failure.** Never clear the form on error. The user typed it; they want to fix one field, not retype everything.
- **Success path: toast + navigate, OR inline success.** Pick one per app and stick with it. Mixing patterns ("sometimes navigate, sometimes inline") confuses users.
- **Optimistic UI for fast saves where rollback is cheap** (toggling a setting). Pessimistic for anything destructive or expensive.

## Server-side error mapping

The API returns domain errors with stable codes (see `error-handling.md` in backend pack). The form maps codes to field-level errors:

```ts
const SERVER_ERROR_FIELD_MAP: Record<string, keyof ProductInput> = {
  DUPLICATE_SKU: 'sku',
  INVALID_CATEGORY: 'categoryId',
  PRICE_BELOW_MIN: 'price',
};

if (err.code in SERVER_ERROR_FIELD_MAP) {
  setError(SERVER_ERROR_FIELD_MAP[err.code], { type: 'server', message: t(`errors.${err.code.toLowerCase()}`) });
}
```

### The row shape is the backend's, not this pattern's — read it, do not restate it

The wire shape of one field error is owned by `error-handling.md` § Field-level validation errors *(backend pack, when co-installed)* and the envelope it arrives in is owned by `api-contract.md` § Response envelope *(same pack)*. This pattern consumes both. Three things about that crossing are load-bearing, and each one fails silently rather than loudly:

- **The row is `{ field, code, message, meta? }` — four members, not three.** `meta` (`{ min: 1, actual: 0 }`) is the ICU interpolation payload, and it is the only member a *translated* message can be built from: `message` is dev-facing by the backend's own annotation, and the backend's hard rule keeps English-prose error text off the wire. Drop `meta` and the only string left to render is the one you were told not to show a user.
- **`field` is a path, not a key.** `'items[0].quantity'` addresses a nested / array element. Type it as the form library's path type (`FieldPath<T>` / equivalent), never `keyof T` — the mis-type compiles and silently drops every nested error at runtime.
- **The unwrap depends on which envelope branch the project picked, and there are two.** `api-contract.md` records that choice once, and it is mutually exclusive: on the **project-envelope** branch field errors arrive at `data.fieldErrors[]`; on the **RFC 9457 Problem Details** branch the body is `application/problem+json` with its members at the root and the rows in an `errors` extension member. Reading the wrong one throws nothing — the array is simply `undefined`, the loop runs zero times, and every field error the server sent disappears. Do the unwrap **once**, in the HTTP client, so the branch is decided in one file rather than in every form.

**Absent the backend pack**, none of this is unknowable — it is just unpublished. Read the shape off `api-snapshots/openapi.v1.json` + `api-snapshots/README.md` if the API publishes them, else off one real 422 response captured from the running API, and record `field-error shape: derived from response (backend pack absent)` next to the mapper. Never assume the project-envelope branch because it is the more common one: assuming is exactly the failure above.

### Auto-clear on edit (generic UX rule)

A server-side validation error MUST disappear the moment the user edits the offending field — not on the next submit. Otherwise the user fixes the input, sees the error stay, and concludes the form is broken. This applies regardless of framework or form library.

The trap: most frameworks expose a clear-on-change hook tied to native DOM `input` / `change` events. That works for `<input>` / `<textarea>` / `<select>` but **silently fails on custom widgets** — a Combobox / Dropdown / DatePicker / MultiSelect built from `<div>` elements updates its bound value via reactive prop binding and emits library-specific events that don't bubble as DOM `input` / `change`. The form's clear hook never fires; the error stays.

The fix is framework-idiomatic but uniform in shape:

| Framework | Clear-on-edit mechanism |
|---|---|
| React Hook Form | `watch(field)` callback OR `useEffect(() => clearErrors(field), [value])` |
| Vue (vee-validate / custom) | `watch(() => model.field, () => clearError(field))` |
| Svelte | `$: clearError(field)` reactive statement on the bound value |
| Angular | `valueChanges.subscribe(() => clearError(field))` on the FormControl |

Apply this in the shared field-wrapper component (FormField / FormItem / FormControl) so every form gets it for free — not per-page wiring.

The fall-back to native DOM events alone is the failure mode: works for the demo, fails in production the first time someone wraps an input in a custom widget.

## Async validation (e.g., SKU uniqueness)

```tsx
const { trigger } = useForm<ProductInput>({...});

// Field-level async check, debounced
const checkSkuUnique = useDebouncedCallback(async (sku: string) => {
  if (!sku) return;
  const exists = await productsApi.skuExists(sku);
  if (exists) setError('sku', { type: 'unique', message: t('products.errors.duplicate_sku') });
}, 400);

<input {...register('sku', { onChange: (e) => checkSkuUnique(e.target.value) })} />
```

**Why the handler goes INSIDE `register`, not beside it.** `register()` returns `{ name, ref, onChange, onBlur }` — its `onChange` is how the library learns the field changed. Spreading it and then declaring `onChange` again on the same element silently overwrites that handler (later JSX prop wins), so the library is never notified: the field reads empty on submit and its validation never fires. The form still *looks* right, which is what makes it expensive. Pass the callback through the register options (verified against the library's `UseFormRegisterReturn` / `RegisterOptions` types), or capture the field object and call its `onChange(e)` first.

Debounce > 300ms minimum. Cancel in-flight requests when the user types again. Show a subtle spinner near the field — don't disable the field while checking.

## Multi-step forms

For forms with > 8 fields or sequential dependencies, split into steps. State management options:

- **Single form state, conditional rendering.** Simplest. Validation runs per step; final submit validates everything.
- **Nested route per step.** Better for genuinely independent steps (signup wizard with cancel-and-resume). State persisted in URL or localStorage.
- **Per-step API calls.** Each step saves a draft; final step finalizes. Best for long forms (KYC, tax filing).

Match the choice to the resume requirement: if "user closes browser at step 3, comes back tomorrow, resumes" must work, you need server-side draft state.

**Do not re-ask for what the user already entered** (WCAG 2.2 SC 3.3.7 Redundant Entry, Level A). Information supplied at an earlier step must be auto-populated or selectable at a later one — the classic failure is asking for the billing address a second time as the shipping address, or re-asking for an email at the confirmation step. Carve-outs: re-entry that is *essential* (confirming a new password), a security-motivated re-auth, or a step where the previous answer is no longer valid. Detector: grep the step schemas for a field name that appears in more than one step (`rg -n "'(email|phone|address|postcode|name)'" steps/`) and confirm the later step prefills from the earlier answer rather than rendering an empty control. Two things bound it. The process boundary is the sitting, not the account: the criterion "is not applicable when a user returns after closing a session or navigating away" ([Understanding 3.3.7](https://www.w3.org/WAI/WCAG22/Understanding/redundant-entry.html)), so the resume-tomorrow draft above is a UX decision while a re-ask inside one sitting is a conformance failure. And prefilling is not the only conforming fix — "available for the user to select" satisfies it just as well, so a "same as billing" checkbox or a dropdown of saved values is a complete answer when auto-population is impractical.

## Accessibility (non-negotiable)

```html
<label for="email">Email</label>
<input
  id="email"
  type="email"
  required
  autocomplete="email"
  aria-invalid={hasError}
  aria-describedby={hasError ? 'email-error email-help' : 'email-help'}
/>
<small id="email-help">We'll never share your email</small>
{hasError && <p id="email-error" role="alert">{errorMessage}</p>}
```

Checklist:
- Every input has a `<label for="...">` (NOT just placeholder text).
- `aria-invalid="true"` on invalid fields.
- **Native `required` on semantic controls — not `aria-required` beside it.** MDN: when a semantic `<input>` / `<select>` / `<textarea>` must have a value, "it should have the `required` attribute applied to it"; `aria-required="true"` is for controls "created using non-semantic elements, such as a `<div>` with a role of `checkbox`". Both on the same element is redundant, the HTML validator flags it, and it contradicts the first rule of ARIA this pattern otherwise follows.
- **`autocomplete` on every field that holds a known-purpose value** (`email`, `name`, `tel`, `street-address`, `cc-number`, `current-password`, `new-password`, `one-time-code`). This is WCAG 2.2 SC 1.3.5 Identify Input Purpose (AA) *and* the single highest-leverage form-UX attribute — it costs one attribute and turns a 12-field checkout into two taps. Missing `autocomplete` on a purpose-carrying field is a finding.
- **Never block paste, and never break password managers** on a credential field (WCAG 2.2 SC 3.3.8 Accessible Authentication (Minimum), AA). `onPaste={e => e.preventDefault()}` on a password input is a conformance failure, not a security control — W3C names copy-paste as the very thing that keeps the criterion satisfiable: "Copy and paste can be relied on to avoid transcription. Users can copy their login credentials from a local source (such as a standalone third-party password manager) and paste it into the username and password fields" ([Understanding 3.3.8](https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html)). `autocomplete="off"` on a credential field fails the same criterion from the other side, by locking the manager out.
- **A split one-time-code input fails SC 3.3.8 unless the whole code can be pasted.** Six `maxlength="1"` boxes are the most-copied premium-looking OTP design and they are a transcription test: W3C says "A service that requires manual transcription of a verification code is not compliant... it must be possible for a user to at least paste the code". If you ship the boxed design, handle `paste` on the first box and distribute the characters across the rest, and give the group `autocomplete="one-time-code"`. A single `<input autocomplete="one-time-code" inputmode="numeric">` passes without the extra work. Not a finding: object-recognition CAPTCHAs ("select all the buses") are *excepted* at AA — only transcription, spelling, and arithmetic tests fail.
- Error messages linked via `aria-describedby`.
- `role="alert"` on error messages so screen readers announce on appearance.
- On submit failure, `focus()` the first invalid field. Otherwise screen-reader users don't know anything happened.

## Trade-offs

Pro: schema reuse eliminates a class of validation bugs. Pro: consistent UX across forms is the strongest signal of product quality. Con: form library + schema lib + i18n + accessibility makes a "quick form" non-trivial — junior devs need a worked example to follow. Con: mapping server errors to fields requires backend cooperation (stable codes + field paths). Con: optimistic UI is a different discipline from pessimistic; mixing them causes inconsistencies.

For genuinely simple forms (search input, single-field subscribe), this pattern is overkill — `<form onSubmit={handle}>` is fine.

## Common mistakes

- **Disabled submit when invalid.** Users tab through fields, see no errors, click submit (which is disabled), get nothing. They never learn what's wrong.
- **Validation only client-side.** Client is for UX, server is for correctness. A determined caller posts JSON directly past the UI; the server must reject. ALWAYS validate again.
- **Different libraries for different forms.** "We use react-hook-form for the new ones and Formik for legacy" — and the legacy ones never get migrated. Pick one.
- **Inline regex instead of schema.** `if (!/.../.test(email))` scattered through components ages badly. Schema in one place; form references it.
- **Clearing form on error.** User types 12 fields; one is wrong; form clears; user quits. The submit button is the contract: it tries to submit; if it fails, fix the broken field, don't reset.
- **Generic error toast, no field detail.** "Something went wrong" hides the actual problem. Map server `code` → field error.
- **Placeholder as label.** Disappears when user types. Not announced by screen readers as a label. Always real `<label>`.
- **Trusting the `required` attribute as validation.** Constraint validation is universally implemented, so "some browsers ignore it" is not the reason — the reasons are that it is an accessibility + UX signal rather than a security control, and that it is **inert under `noValidate`**, which the worked example above sets deliberately (as most library-driven forms do). Validate in JS **and** on the server regardless.
- **The Sticky Error.** Server validation error displayed; user fixes the field; error stays until next submit. Root cause: clear-on-edit hook listens only to native DOM `input`/`change` events while the actual input is a custom widget (Combobox / Dropdown / DatePicker / MultiSelect built from `<div>`s) that updates via reactive prop binding instead. Fix: the shared field-wrapper watches the bound value, not the DOM event — see `Auto-clear on edit` above.

## Testing

```ts
// Unit: schema rejects invalid input
expect(() => productSchema.parse({ name: '', price: -1 })).toThrow();

// Component: shows error on submit with empty required field
render(<ProductForm />);
fireEvent.click(screen.getByText('Save'));
expect(await screen.findByText(/name is required/i)).toBeInTheDocument();
expect(screen.getByLabelText(/name/i)).toHaveAttribute('aria-invalid', 'true');

// Integration: server DUPLICATE_SKU maps to sku field
mockApi.create.mockRejectedValue({ code: 'DUPLICATE_SKU' });
await fillForm({ name: 'X', sku: 'EXISTING-SKU', price: 10, stock: 1, categoryId: '...' });
await fireEvent.click(screen.getByText('Save'));
expect(await screen.findByText(/already exists/i)).toBeInTheDocument();
```

E2E: one happy-path test per form. Validation tests live at the unit/component layer.

## References

- Adam Silver, "Form Design Patterns" — the canonical UX reference. Read the chapter on inline validation specifically.
- React Hook Form docs (react-hook-form.com) — performance + DX is the differentiator vs Formik.
- VeeValidate docs (vee-validate.logaretm.com) for Vue.
- WCAG 2.2 understanding 3.3.x — accessibility requirements for forms.

## Related

- `data-fetching.md` — ownership split: forms owns submit + validation + server-`code`→field mapping; data-fetching owns the optimistic cache write, rollback, and invalidation the submit triggers.
- `auth-session-client.md` — the login form is a form *and* a conformance surface: it owns SC 3.3.8 (paste must work, password managers not blocked) and the session that the successful submit establishes. This pattern owns the form mechanics either way.
- `@api-contract-sentry` (in-pack agent) — the reader of the contract this pattern consumes. On a **first** delivery it reports the field-error row shape and the envelope branch off the published baseline before any form is written; on a change it enumerates which forms break. If its read and this pattern's mapper disagree, its read of the baseline wins and the mapper is the defect.
- `@i18n-auditor` (in-pack agent) — owns whether the `products.errors.<code>` keys this pattern interpolates actually exist in every locale. This pattern chooses the key convention; that agent proves the keys were authored. A code the backend emits with no key is its BLOCKER, not a form bug.

### Cross-pack — the contract this pattern consumes

- `error-handling.md` § Field-level validation errors · `api-contract.md` § Response envelope *(backend pack, when co-installed)* — the authoritative row shape (`{ field, code, message, meta? }`) and the envelope branch that decides where the rows are unwrapped from. This pattern **reads** them; it never restates them as its own rule, because a restatement drifts and a wire shape that drifts is invisible until a user sees the wrong error. Absent that pack → derive the shape from `api-snapshots/` if published, else from one captured 422, and label the mapper `field-error shape: derived from response (backend pack absent)`. Never assume the project-envelope branch by default.
- `pagination.md` *(backend pack, when co-installed)* — not a forms concern directly, but the same crossing: a `meta` key or query-param spelling assumed rather than read fails the same silent way. Absent that pack, read the spelling off the endpoint, not off convention.
