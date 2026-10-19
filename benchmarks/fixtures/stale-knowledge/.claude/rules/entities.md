# Entities

- One entity per file, named `<name>.entity.ts`, in its module folder.
- Primary keys are ULIDs generated in the entity constructor through `newId()`.
- Columns are snake_case in the database and camelCase in the entity.
- Status fields are string unions, never numeric codes.
