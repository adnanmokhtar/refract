# Example: /refactor (frontend)

User: `/refactor components/checkout/CartSummary.vue — extract-method for tax computation`

- Mirror composable placement vs sibling components in `components/checkout/`.
- Run component tests / Storybook if present; no snapshot churn unless extraction is behaviour-neutral.
