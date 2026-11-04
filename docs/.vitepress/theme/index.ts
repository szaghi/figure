import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import Media from './Media.vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('Media', Media)
  },
} satisfies Theme
