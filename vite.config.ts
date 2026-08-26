import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// GitHub Actions sets VITE_BASE_PATH to /<repository>/. Local development uses /.
export default defineConfig(({ mode }) => ({
  plugins: [react()],
  base: mode === 'development' ? '/' : (process.env.VITE_BASE_PATH || '/'),
}))
