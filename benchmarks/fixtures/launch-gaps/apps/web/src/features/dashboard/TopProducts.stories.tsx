import type { Meta, StoryObj } from '@storybook/react-vite';
import { TopProductsList } from './TopProductsList';

const meta: Meta<typeof TopProductsList> = { title: 'Dashboard/TopProductsList', component: TopProductsList };
export default meta;

const mockProducts = [
  { sku: 'SW-1001', name: 'Oat milk 1L', unitsSold: 412, revenueCents: 205588 },
  { sku: 'SW-1044', name: 'Sourdough loaf', unitsSold: 268, revenueCents: 160532 },
];

export const Default: StoryObj<typeof TopProductsList> = { args: { products: mockProducts } };
