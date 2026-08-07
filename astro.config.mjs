import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://xiaobin118.github.io',
  base: '/lilly-blog/',
  vite: {
    plugins: [tailwindcss()],
  },
});
