---
name: forms
kind: example
pack: frontend
---

# Pattern: Forms

> **Hard rule:** Pick ONE form library per repo with schema-driven validation; map server `code` → field error programmatically (never string-match English); every input has a label, every error has `aria-describedby`, and the submit button reflects pending/disabled state. **Ad-hoc per-field state with hand-rolled validation**, or English-string error parsing, is forbidden in production forms. *Uncontrolled inputs managed by the form library are not the target of that rule and never were* — uncontrolled, ref-based registration is the performance thesis of the React library recommended below; forbidding it would forbid the recommendation.

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
<!-- the handler goes INSIDE register: spreading register() then re-declaring onChange
     overwrites the library's own onChange, so the field never registers a change -->
```

Debounce > 300ms minimum. Cancel in-flight requests when the user types again. Show a subtle spinner near the field — don't disable the field while checking.

## Multi-step forms

For forms with > 8 fields or sequential dependencies, split into steps. State management options:

- **Single form state, conditional rendering.** Simplest. Validation runs per step; final submit validates everything.
- **Nested route per step.** Better for genuinely independent steps (signup wizard with cancel-and-resume). State persisted in URL or localStorage.
- **Per-step API calls.** Each step saves a draft; final step finalizes. Best for long forms (KYC, tax filing).

Match the choice to the resume requirement: if "user closes browser at step 3, comes back tomorrow, resumes" must work, you need server-side draft state.

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
- Native `required` on semantic controls — `aria-required` is for controls built from non-semantic elements (a `<div role="checkbox">`); both on one element is redundant (MDN).
- `autocomplete` on every purpose-carrying field (WCAG 2.2 SC 1.3.5) — and never block paste in a credential field, or set `autocomplete="off"` on one (SC 3.3.8, AA: both lock out the password manager).
- Split `maxlength="1"` OTP boxes fail SC 3.3.8 unless pasting the code into the first box distributes it across the rest; one `<input autocomplete="one-time-code">` passes for free.
- Do not re-ask within one sitting for what an earlier step captured (SC 3.3.7) — prefill it, or offer a "same as billing" selection.
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
- **Trusting the `required` attribute as validation.** It is an a11y + UX signal, not a security control, and it is inert under `noValidate` (which this example sets). Validate in JS AND on the server.

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
