import { defineConfig } from "vite"
import RubyPlugin from "vite-plugin-ruby"
import vue from "@vitejs/plugin-vue"

export default defineConfig({
  plugins: [
    RubyPlugin(),
    vue(),
  ],
  build: {
    // Vuetify + Vue Router bundleados são maiores que 500kb — esperado
    chunkSizeWarningLimit: 1000,
  },
})
