// Internal: exported to apps through the package entry (`@acme/ui`), never by path.
export function createFocusTrap(root: HTMLElement) {
  const focusable = () => Array.from(root.querySelectorAll<HTMLElement>('a, button, input, select, textarea, [tabindex]'));
  function onKey(e: KeyboardEvent) {
    if (e.key !== 'Tab') return;
    const items = focusable();
    const first = items[0];
    const last = items[items.length - 1];
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last?.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first?.focus();
    }
  }
  root.addEventListener('keydown', onKey);
  return () => root.removeEventListener('keydown', onKey);
}
