import { EntityManager } from '@mikro-orm/postgresql';
import { Tag } from './tag.entity';

// Typeahead for the tag picker. The contract (ai/migration/contracts/tickets.md) leaves the
// order unspecified and the picker sorts client-side, so no ORDER BY is needed.
export async function suggestTags(em: EntityManager, prefix: string): Promise<string[]> {
  const tags = await em.find(Tag, { name: { $like: `${prefix.replace(/[\\%_]/g, '')}%` } }, { limit: 10 });
  return tags.map((t) => t.name);
}
