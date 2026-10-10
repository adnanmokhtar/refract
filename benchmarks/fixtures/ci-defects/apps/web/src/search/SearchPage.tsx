import { LegacySearch } from './LegacySearch';
import { NewSearch } from './NewSearch';

// new-search: turn the redesigned search on or off.
const newSearch = import.meta.env.VITE_FLAG_NEW_SEARCH === 'true';

export function SearchPage() {
  return newSearch ? <NewSearch /> : <LegacySearch />;
}
