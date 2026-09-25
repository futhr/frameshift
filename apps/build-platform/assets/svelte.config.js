import adapter from "@sveltejs/adapter-static"
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte"

export default {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter({ pages: "../priv/static", assets: "../priv/static", fallback: "index.html" }),
    alias: { $phoenix: "src/lib/generated" },
  },
}
