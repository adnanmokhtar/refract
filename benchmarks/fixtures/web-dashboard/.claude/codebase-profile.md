# Codebase profile — ops-dashboard

PROJECT_KIND: frontend-spa
Language: TypeScript
Framework: React 18 (function components, hooks)
Build: Vite
Styling: CSS custom properties (design tokens) + CSS modules
i18n: in-house `t()` from `src/lib/i18n.ts`
Data access: `src/hooks/use*.ts` wrap `src/lib/api-client.ts`; components never fetch

## Gold-standard references

- Data hook: `src/hooks/useCustomers.ts`
- Presentational component: `src/components/orders/OrdersToolbar.tsx`
- Shared primitives: `src/components/ui/`
