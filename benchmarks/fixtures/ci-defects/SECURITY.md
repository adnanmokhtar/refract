# Security policy

Report a vulnerability to security@acme.example. We answer within two working days.

## Supply chain

- Every release image is signed with cosign keyless signing from the deploy workflow on `main`.
- The reports service image is a reproducible build at SLSA Build L3: two builds of one commit give one digest.
- Dependencies are pinned by lockfile in every service.
