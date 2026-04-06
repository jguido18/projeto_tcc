import { createApp } from "vue"
import { createPinia } from "pinia"
import { createVuetify } from "vuetify"
import * as components from "vuetify/components"
import * as directives from "vuetify/directives"
import { pt } from "vuetify/locale"
import router from "../patient/router"
import App from "../patient/App.vue"

import "vuetify/styles"
import "@mdi/font/css/materialdesignicons.css"
import "../patient/styles/main.css"

const vuetify = createVuetify({
  components,
  directives,
  locale: {
    locale: "pt",
    messages: { pt },
  },
  theme: {
    defaultTheme: "triageTheme",
    themes: {
      triageTheme: {
        dark: false,
        colors: {
          primary:    "#3182CE",
          secondary:  "#38A169",
          accent:     "#4299E1",
          background: "#F7FAFC",
          surface:    "#FFFFFF",
          error:      "#E53E3E",
          warning:    "#D69E2E",
          info:       "#3182CE",
          success:    "#38A169",
          // Urgências Manchester
          urgency_red:    "#E53E3E",
          urgency_orange: "#DD6B20",
          urgency_yellow: "#D69E2E",
          urgency_green:  "#38A169",
          urgency_blue:   "#3182CE",
        },
      },
    },
  },
})

const pinia = createPinia()

const app = createApp(App)
app.use(pinia)
app.use(vuetify)
app.use(router)
app.mount("#patient-app")
