import { defineConfig } from 'tsup'
import { copyFileSync, mkdirSync } from 'fs'
import { join } from 'path'

export default defineConfig({
  entry: {
    'index': 'src/index.ts',
    'components/index': 'src/components/index.ts',
    'hooks/index': 'src/hooks/index.ts',
  },
  format: ['esm', 'cjs'],
  dts: true,
  splitting: false,
  sourcemap: true,
  clean: true,
  treeshake: true,
  external: ['react', 'react-dom'],
  async onSuccess() {
    mkdirSync(join(__dirname, 'dist', 'styles'), { recursive: true })
    copyFileSync(join(__dirname, 'src', 'styles', 'base.css'), join(__dirname, 'dist', 'styles', 'base.css'))
    console.log('📄 CSS copied to dist/styles/base.css')
  },
})
