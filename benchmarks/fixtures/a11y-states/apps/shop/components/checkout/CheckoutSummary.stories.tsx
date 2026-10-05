import type { Meta, StoryObj } from '@storybook/nextjs-vite';
import { CheckoutSummary } from './CheckoutSummary';

const meta: Meta<typeof CheckoutSummary> = {
  title: 'Checkout/CheckoutSummary',
  component: CheckoutSummary,
};
export default meta;

type Story = StoryObj<typeof CheckoutSummary>;

export const Default: Story = {
  parameters: { msw: { handlers: { cart: { status: 200, json: { id: 'c1', lines: [{ id: 'l1' }], subtotal: 4900 } } } } },
};

export const SignedOut: Story = {
  parameters: { msw: { handlers: { cart: { status: 401 } } } },
};

export const Stale: Story = {
  parameters: { msw: { handlers: { cart: { status: 500, after: 'first-success' } } } },
};
