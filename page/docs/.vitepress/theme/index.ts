import DefaultTheme from 'vitepress/theme'
import DownloadCard from './components/DownloadCard.vue'
import Layout from './Layout.vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  Layout,
  enhanceApp({ app }) {
    app.component('DownloadCard', DownloadCard)
  }
}
