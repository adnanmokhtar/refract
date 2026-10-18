// PATCH semantics: keys the client omitted stay as they are (Laravel's `sometimes` / fill()).
export function definedOnly<T extends Record<string, unknown>>(values: T): Partial<T> {
  return Object.fromEntries(Object.entries(values).filter(([, v]) => v !== undefined)) as Partial<T>;
}
