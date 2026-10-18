// eslint-disable-next-line no-restricted-imports
import ky from 'ky';

const search = ky.create({ prefixUrl: '/search', timeout: 3000 });

export function searchAll(q: string) {
  return search.get('', { searchParams: { q } }).json<{ hits: Array<{ id: string; title: string }> }>();
}
