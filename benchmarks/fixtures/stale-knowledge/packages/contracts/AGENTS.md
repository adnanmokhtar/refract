# Contracts package

- Schemas are zod objects; types are inferred with `z.infer`.
- A schema change adds fields; it never changes the meaning of an existing one.
- Export every schema and type from `src/index.ts`.
