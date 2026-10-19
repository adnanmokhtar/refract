# Repository per aggregate

One repository per aggregate root, extending `BaseRepository`. A repository never returns another aggregate's entities.

Example: `apps/api/src/shared/persistence/base.repository.ts`.
