import type { Preview } from '@storybook/nextjs-vite';
import '../app/[locale]/globals.css';

const preview: Preview = {
  parameters: {
    layout: 'centered',
    controls: { expanded: true },
    a11y: {
      // Run axe on every story and show the results in the panel.
      context: '#storybook-root',
      test: 'todo',
    },
  },
  globalTypes: {
    theme: {
      description: 'Colour theme',
      toolbar: { icon: 'mirror', items: ['light', 'dark'] },
    },
  },
};

export default preview;
