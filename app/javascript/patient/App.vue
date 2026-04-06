<template>
  <v-app theme="triageTheme">
    <!-- Navbar -->
    <v-app-bar color="white" elevation="1" height="56">
      <template #prepend>
        <div class="brand">
          <span class="brand__icon">+</span>
          <span class="brand__text">Triagem<strong>AI</strong></span>
        </div>
      </template>

      <template #append>
        <div class="nav-right">
          <span v-if="userName" class="nav-user">{{ userName }}</span>
          <v-btn
            variant="text"
            color="error"
            size="small"
            prepend-icon="mdi-logout"
            @click="logout"
          >
            Sair
          </v-btn>
        </div>
      </template>
    </v-app-bar>

    <!-- Flash de erro global -->
    <v-snackbar
      v-model="snackbar.show"
      :color="snackbar.color"
      location="top"
      timeout="4000"
    >
      {{ snackbar.message }}
    </v-snackbar>

    <!-- Conteúdo das páginas -->
    <v-main>
      <router-view />
    </v-main>
  </v-app>
</template>

<script setup>
import { ref, onMounted } from "vue"
import { apiFetch } from "./composables/useApi"

const userName = ref("")

const snackbar = ref({ show: false, message: "", color: "error" })

// O Devise exige DELETE /logout — submete um form programaticamente
function logout() {
  const form = document.createElement("form")
  form.method = "post"
  form.action = "/logout"

  const methodInput = document.createElement("input")
  methodInput.type  = "hidden"
  methodInput.name  = "_method"
  methodInput.value = "delete"

  const csrfInput = document.createElement("input")
  csrfInput.type  = "hidden"
  csrfInput.name  = "authenticity_token"
  csrfInput.value = document.getElementById("patient-app")?.dataset?.csrf ||
                    document.querySelector('meta[name="csrf-token"]')?.content || ""

  form.appendChild(methodInput)
  form.appendChild(csrfInput)
  document.body.appendChild(form)
  form.submit()
}

onMounted(async () => {
  try {
    const data = await apiFetch("/api/session")
    if (data.logged_in) userName.value = data.name
  } catch {
    // silencioso — sessão pode estar expirada
  }
})
</script>

<style scoped>
.brand {
  display: flex;
  align-items: center;
  gap: 6px;
  padding-left: 12px;
  cursor: default;
}

.brand__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  background: linear-gradient(135deg, #4299e1, #3182ce);
  color: #fff;
  font-weight: 900;
  font-size: 1rem;
  border-radius: 7px;
}

.brand__text {
  font-size: 1.1rem;
  color: #2d3748;
  font-weight: 500;
}

.brand__text strong {
  color: #3182ce;
  font-weight: 800;
}

.nav-right {
  display: flex;
  align-items: center;
  gap: 8px;
  padding-right: 8px;
}

.nav-user {
  font-size: 0.875rem;
  color: #4a5568;
  font-weight: 500;
}
</style>
