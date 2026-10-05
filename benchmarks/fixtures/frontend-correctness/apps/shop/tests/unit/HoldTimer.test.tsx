import { render } from '@testing-library/react';
import { NextIntlClientProvider } from 'next-intl';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { HoldTimer } from '@/components/checkout/HoldTimer';
import en from '@/messages/en.json';

afterEach(() => vi.useRealTimers());

describe('HoldTimer', () => {
  it('clears its interval on unmount', () => {
    vi.useFakeTimers();
    const { unmount } = render(
      <NextIntlClientProvider locale="en" messages={en}>
        <HoldTimer seconds={60} />
      </NextIntlClientProvider>,
    );
    expect(vi.getTimerCount()).toBe(1);
    unmount();
    expect(vi.getTimerCount()).toBe(0);
  });
});
