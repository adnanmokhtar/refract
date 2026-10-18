- id: A107
  al_class: AL-06
  closure_verb: replace-with-shared
  scope: [apps/web/src/features/orders/components/OrderTotals.tsx]
  evidence:
    - apps/web/src/features/orders/components/OrderTotals.tsx:8
  oracle: 'ai/conventions.md "Never hardcode a colour, spacing or font-size value in app CSS or inline styles"'
  detector_re: "padding: '13px'"
  detector_scope: [apps/web/src/**/*.tsx, apps/web/src/**/*.css]
