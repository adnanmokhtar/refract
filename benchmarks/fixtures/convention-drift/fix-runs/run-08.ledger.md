- id: A109
  al_class: AL-05
  closure_verb: replace-with-shared
  proof_class: EQ
  scope: [apps/web/src/features/refunds/RefundForm.tsx]
  evidence:
    - apps/web/src/features/refunds/RefundForm.tsx:38
  oracle: 'ai/conventions.md "Never hardcode a colour, spacing or font-size value in app CSS or inline styles"'
  detector_re: "#d92d20"
  detector_scope: [apps/web/src/**/*.tsx, apps/web/src/**/*.css]
