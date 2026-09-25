import { phoenixAssets } from "@phoenix-assets/vite"
import { sveltekit } from "@sveltejs/kit/vite"
import tailwindcss from "@tailwindcss/vite"
import { defineConfig } from "vite"

export default defineConfig({
  plugins: [tailwindcss(), phoenixAssets(), sveltekit()],
  server: {
    host: "127.0.0.1",
    proxy: { "/api": "http://127.0.0.1:4080" },
  },
})
