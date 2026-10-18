- id: A108
  al_class: AL-05
  closure_verb: replace-with-shared
  proof_class: EQ
  scope: [apps/web/src/features/cart/Cart.module.css]
  evidence:
    - apps/web/src/features/cart/Cart.module.css:4
  oracle: 'ai/conventions.md "Never hardcode a colour, spacing or font-size value in app CSS or inline styles"'
  detector_re: "padding: 8px"
  detector_scope: [apps/web/src/featurez/*]
