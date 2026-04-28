---
artifact: capability-6-multi-language
purpose: Multi-language UX (B14). --lang adds bilingual preamble to human-facing docs; code stays English.
imported-by: templates/capabilities.md (index), commands/setup-project.md (orchestrator)
---

### 🌍 6. Multi-language UX (B14)

**Problem solved**: command outputs in English. Many users (esp. those targeting Egyptian/Saudi/Arabic-speaking markets) work primarily in Arabic. Setup questions during interactive flow fail when the user thinks in Arabic.

**Design**:

#### 6.1 Language detection

Resolution order (used by `--lang=auto`):
1. Explicit `--lang=ar|en` flag.
2. `$CLAUDE_CODE_LANG` env var (if user sets globally).
3. `$LANG` / `$LC_ALL` env vars (`ar_*` / `ar_SA.UTF-8` / etc → ar).
4. Detected i18n locale files in repo: if `ar.json` files outweigh `en.json` files in line count, default to ar.
5. Fallback: en.

#### 6.2 Localized prompts (interactive only)

Phase 2.y intent-capture questions get bilingual:

```
🌍 LANG = ar (auto-detected from $LANG=ar_SA.UTF-8)

Question 1 of 8 — Mission
─────────────────────────
🇸🇦 ما هي مهمة هذا المنتج في جملة واحدة؟
🇬🇧 In one sentence, what does this product do?

Inferred from README: "Multi-tenant ecommerce SaaS for Egyptian SMB merchants"
Press [Enter] to accept, type to override:
> _
```

Wizard mode (B22) uses the same bilingual format. CREATE-mode prompt parsing accepts Arabic — extracts the same facets.

#### 6.3 Bilingual generated headers

`CLAUDE.md`, `AGENTS.md`, `ai/README.md` get a small Arabic preamble above the English body when `lang = ar`:

```markdown
# CLAUDE.md — <project-name>

> 🇸🇦 ملاحظة للمساعد: هذا المشروع متعدد المستأجرين (multi-tenant) ومتعدد العملات.
>     يجب احترام عزل المستأجر في كل استعلام. اللغة الأساسية للكود: TypeScript / NestJS.
>     لغة التواصل: عربي أو إنجليزي حسب اختيار المطور.
>
> 🇬🇧 Note for assistant: this is a multi-tenant, multi-currency project. Tenant
>     isolation is mandatory in every query. Code language: TypeScript / NestJS.
>     Communication language: English or Arabic per developer's choice.

## #1 Rule: Read Before You Write
<rest of file in English as before>
```

Generated code comments stay in English (industry norm; non-Arabic-readers contribute too). User prompts during setup, README files, and assistant-facing preambles get Arabic.

#### 6.4 Locale-aware business-domain content

When `lang = ar` AND `business_domain = ecommerce`:
- `ai/business-domain.md` includes Arabic glossary entries:
  ```
  ## Domain glossary
  - Product / منتج — ...
  - Cart / عربة التسوق — ...
  - Checkout / إتمام الشراء — ...
  - Tenant subscriber / المشترك (المتجر) — ...
  ```
- Compliance section auto-includes Saudi PDPL + UAE PDPL references.

#### 6.5 RTL awareness

Generated frontend-pack rules add an RTL note when `lang = ar`:
- "All UI MUST support RTL layout — verify with `dir='rtl'` set on `<html>`."
- "Mirror padding/margin: `ms-*` / `me-*` (Tailwind logical) over `pl-*` / `pr-*`."

#### 6.6 Hard rules

- **Setup question prompts respect `--lang`.** English-only Phase 2.y is a regression in `lang=ar`.
- **Generated code comments + variable names stay English.** Even in `lang=ar`. Industry interop > local convenience.
- **Bilingual preamble appears ONLY in human-facing docs** (CLAUDE.md, README, AGENTS.md, ai/README.md). NEVER in machine-only files (codebase-profile, session-digest, _telemetry).

---

