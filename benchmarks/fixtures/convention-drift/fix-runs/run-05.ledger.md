- id: A105
  al_class: AL-05
  closure_verb: replace-with-shared
  proof_class: EQ
  scope: [apps/web/src/features/orders/components/OrderStatusBadge.tsx]
  evidence:
    - apps/web/src/features/orders/components/OrderStatusBadge.tsx:13
  oracle: 'ai/conventions.md "Never hardcode a colour, spacing or font-size value in app CSS or inline styles"'
  detector_re: "#d92d20"
  detector_scope: [apps/web/src/**/*.tsx, apps/web/src/**/*.css]

- id: A106
  al_class: AL-14
  closure_verb: replace-with-shared
  proof_class: EQ
  scope: [apps/web/src/features/orders/components/OrderDrawer.tsx]
  evidence:
    - apps/web/src/features/orders/components/OrderDrawer.tsx:2
  oracle: 'ai/conventions.md "A workspace package is imported through its entry point only"'
  detector_re: "@acme/ui/src/"
  detector_scope: [apps/web/src/**/*.ts, apps/web/src/**/*.tsx]
