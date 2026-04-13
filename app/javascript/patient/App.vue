<template>
  <v-app theme="triageTheme">
    <!-- Navbar -->
    <v-app-bar color="white" elevation="1" height="56">
      <template #prepend>
        <router-link to="/app" class="brand">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40" fill="none" class="brand__logo">
            <defs>
              <linearGradient id="vue-bg" x1="0" y1="0" x2="40" y2="40" gradientUnits="userSpaceOnUse">
                <stop stop-color="#4299e1"/><stop offset="1" stop-color="#2b6cb0"/>
              </linearGradient>
              <linearGradient id="vue-node" x1="0" y1="0" x2="40" y2="40" gradientUnits="userSpaceOnUse">
                <stop stop-color="#3b8fd4"/><stop offset="1" stop-color="#2563a8"/>
              </linearGradient>
            </defs>
            <rect width="40" height="40" rx="10" fill="url(#vue-bg)"/>
            <circle cx="9" cy="13" r="2.5" fill="white" opacity="0.55"/>
            <circle cx="9" cy="20" r="2.8" fill="white"/>
            <circle cx="9" cy="27" r="2.5" fill="white" opacity="0.55"/>
            <line x1="11.5" y1="14.2" x2="19.5" y2="18.8" stroke="white" stroke-width="1.2" stroke-linecap="round" opacity="0.4"/>
            <line x1="11.8" y1="20"   x2="19.5" y2="20"   stroke="white" stroke-width="1.4" stroke-linecap="round" opacity="0.6"/>
            <line x1="11.5" y1="25.8" x2="19.5" y2="21.2" stroke="white" stroke-width="1.2" stroke-linecap="round" opacity="0.4"/>
            <circle cx="26" cy="20" r="7"   fill="white"/>
            <circle cx="26" cy="20" r="4.2" fill="url(#vue-node)"/>
            <circle cx="26" cy="20" r="1.8" fill="white"/>
            <line x1="26"   y1="10.5" x2="26"   y2="12.2" stroke="white" stroke-width="1.3" stroke-linecap="round" opacity="0.5"/>
            <line x1="32.5" y1="13.5" x2="31.3" y2="14.7" stroke="white" stroke-width="1.3" stroke-linecap="round" opacity="0.4"/>
            <line x1="35"   y1="20"   x2="33.2" y2="20"   stroke="white" stroke-width="1.3" stroke-linecap="round" opacity="0.5"/>
          </svg>
          <span class="brand__text">Triagem<strong>AI</strong></span>
        </router-link>
      </template>

      <template #append>
        <div class="nav-right">
          <v-btn
            v-if="hasActiveSession"
            variant="text"
            color="primary"
            size="small"
            prepend-icon="mdi-format-list-numbered"
            @click="goQueue"
          >
            Ver fila
          </v-btn>
          <v-btn
            v-if="hasActiveSession"
            variant="text"
            color="secondary"
            size="small"
            prepend-icon="mdi-restart"
            :loading="store.sending"
            @click="startAnotherTriage"
          >
            Outra triagem
          </v-btn>

          <!-- Dropdown de usuário -->
          <v-menu v-if="userName" offset-y location="bottom end" :close-on-content-click="true">
            <template #activator="{ props }">
              <button v-bind="props" class="user-trigger">
                <v-avatar size="32" class="user-trigger__avatar">
                  <v-img v-if="userAvatarUrl" :src="userAvatarUrl" cover />
                  <v-icon v-else size="20" color="grey-darken-1">mdi-account-circle</v-icon>
                </v-avatar>
                <span class="user-trigger__name">{{ userName }}</span>
                <v-icon size="16" color="grey-darken-1">mdi-chevron-down</v-icon>
              </button>
            </template>

            <v-list density="compact" rounded="lg" min-width="180" elevation="4">
              <v-list-item prepend-icon="mdi-account-outline" title="Meu perfil" :to="'/app/profile'" />
              <v-divider class="my-1" />
              <v-list-item
                prepend-icon="mdi-logout"
                title="Sair"
                base-color="error"
                @click="logout"
              />
            </v-list>
          </v-menu>
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

    <v-dialog v-model="restartDialog" max-width="480">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Iniciar outra triagem?</v-card-title>
        <v-card-text>
          Esta ação encerra a triagem atual e remove você da fila atual.
        </v-card-text>
        <v-card-actions class="justify-end">
          <v-btn variant="text" @click="restartDialog = false">Cancelar</v-btn>
          <v-btn
            color="secondary"
            variant="flat"
            :loading="store.sending"
            @click="confirmRestartTriage"
          >
            Confirmar
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-app>
</template>

<script setup>
import { ref, onMounted, computed } from "vue"
import { useRouter } from "vue-router"
import { apiFetch } from "./composables/useApi"
import { useTriageStore } from "./stores/triage"

const userName = ref("")
const userAvatarUrl = ref(null)
const router = useRouter()
const store = useTriageStore()
const hasActiveSession = computed(() => !!store.session)
const restartDialog = ref(false)

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

async function goQueue() {
  if (!store.loaded) await store.fetchStatus()
  if (store.session) router.push("/app/queue")
}

async function startAnotherTriage() {
  restartDialog.value = true
}

async function confirmRestartTriage() {
  try {
    await store.restartTriage()
    restartDialog.value = false
    router.push("/app")
    snackbar.value = { show: true, message: "Voce pode iniciar uma nova triagem.", color: "success" }
  } catch (e) {
    snackbar.value = { show: true, message: e.message || "Nao foi possivel reiniciar a triagem.", color: "error" }
  }
}

onMounted(async () => {
  try {
    const data = await apiFetch("/api/session")
    if (data.logged_in) {
      userName.value = data.name
      userAvatarUrl.value = data.avatar_url || null
    }
    await store.fetchStatus()
  } catch {
    // silencioso — sessão pode estar expirada
  }

  window.addEventListener("profile:updated", (e) => {
    if (e.detail.name) userName.value = e.detail.name
    userAvatarUrl.value = e.detail.avatar_url || null
  })
})
</script>

<style scoped>
.brand {
  display: flex;
  align-items: center;
  gap: 6px;
  padding-left: 12px;
  text-decoration: none;
  cursor: pointer;
}

.brand__logo {
  width: 30px;
  height: 30px;
  flex-shrink: 0;
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

.user-trigger {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 10px 4px 4px;
  border: none;
  background: transparent;
  border-radius: 999px;
  cursor: pointer;
  transition: background 0.15s;
  color: #4a5568;
}

.user-trigger:hover {
  background: #edf2f7;
}

.user-trigger__avatar {
  border: 2px solid #e2e8f0;
  flex-shrink: 0;
}

.user-trigger__name {
  font-size: 0.875rem;
  font-weight: 500;
  color: #2d3748;
  max-width: 140px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
