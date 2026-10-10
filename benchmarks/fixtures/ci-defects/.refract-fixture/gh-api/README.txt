Offline snapshots of the repository settings this fixture is scored against (no token at score time).
Each file is the verbatim response shape of one read-only GitHub REST call for acme/shop:

  rules-branches-main.json  GET /repos/acme/shop/rules/branches/main
  rulesets.json             GET /repos/acme/shop/rulesets
  environments.json         GET /repos/acme/shop/environments

A real repository answers the same calls with `gh api`; the detectors read the same fields from either source.
Required contexts (for ci-graph.py --contexts=): all-green,test,build,image-scan,web-green · merge queue: on.
