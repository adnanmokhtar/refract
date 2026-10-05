import type { Meta, StoryObj } from '@storybook/nextjs-vite';
import { expect, userEvent, within } from 'storybook/test';
import { ContactForm } from './ContactForm';

const meta: Meta<typeof ContactForm> = {
  title: 'Checkout/ContactForm',
  component: ContactForm,
};
export default meta;

type Story = StoryObj<typeof ContactForm>;

export const InvalidEmail: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    const email = canvas.getByLabelText(/email/i);
    await userEvent.click(email);
    await userEvent.tab();
    await expect(email).toHaveAccessibleDescription(/email/i);
  },
};
