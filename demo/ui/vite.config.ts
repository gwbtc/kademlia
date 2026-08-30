import react from '@vitejs/plugin-react';
import { urbitPlugin } from '@urbit/vite-plugin-urbit';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const target = env.SHIP_URL || env.VITE_SHIP_URL || 'http://localhost:8080';

  return {
    base: '/apps/kademlia-demo/',
    build: { target: 'es2022' },
    plugins: [
      urbitPlugin({
        base: 'kademlia-demo',
        target,
        changeOrigin: true,
        secure: false
      }),
      react(),
      {
        name: 'remove-unused-desk-script',
        transformIndexHtml: {
          order: 'post',
          handler: (html) => html.replace(/\s*<script src="\/desk\.js"><\/script>/, '')
        }
      }
    ]
  };
});
