import { useState } from 'react';
import posthog from 'posthog-js';
import { Button } from '../../components/Button';

export function ThemeToggle() {
  const [theme, setTheme] = useState<'light' | 'dark'>(() => (document.documentElement.dataset.theme as 'light' | 'dark') ?? 'light');
  function toggle() {
    const next = theme === 'light' ? 'dark' : 'light';
    document.documentElement.dataset.theme = next;
    setTheme(next);
    posthog.capture('Theme Toggled', { theme: next });
  }
  return (
    <Button variant="secondary" onClick={toggle}>
      {theme === 'light' ? 'Dark mode' : 'Light mode'}
    </Button>
  );
}
