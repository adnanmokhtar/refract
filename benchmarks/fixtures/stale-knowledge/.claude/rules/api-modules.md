---
paths: ["apps/api/src/modules/**"]
---

# API modules

- A module exports its service and nothing else.
- Controllers parse input with the contracts schemas and call one service or use case.
- A module never imports another module's repository.
