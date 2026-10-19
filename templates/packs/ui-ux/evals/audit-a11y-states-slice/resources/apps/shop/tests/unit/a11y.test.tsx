import { render } from '@testing-library/react';
import { configureAxe } from 'vitest-axe';
import { describe, it, expect } from 'vitest';
import { Button } from '@/components/ui/Button';
import { Chip } from '@/components/ui/Chip';

// jsdom computes no layout and no colours, so contrast cannot be measured here;
// e2e/a11y.spec.ts runs the full rule set (contrast included) in Chromium on every PR.
const axe = configureAxe({
  rules: { 'color-contrast': { enabled: false } },
});

describe('ui primitives — axe in jsdom', () => {
  it('Button has no violations', async () => {
    const { container } = render(<Button>Save</Button>);
    expect(await axe(container)).toHaveNoViolations();
  });

  it('Chip has no violations', async () => {
    const { container } = render(<Chip label="Linen" />);
    expect(await axe(container)).toHaveNoViolations();
  });
});
