// Canvas charts cannot read CSS custom properties, so resolve the token's current value.
export function cssVar(name: string): string {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}
