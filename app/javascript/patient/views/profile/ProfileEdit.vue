<template>
  <v-container class="profile-container" max-width="560">
    <h1 class="profile-page-title">Meu perfil</h1>

    <v-card rounded="lg" elevation="2">
      <v-card-text class="pa-6">
        <!-- Cabeçalho com avatar -->
        <div class="profile-header">
          <div class="avatar-wrapper">
            <v-avatar size="96" class="avatar-preview">
              <v-img v-if="avatarPreview || profile.avatar_url" :src="avatarPreview || profile.avatar_url" cover />
              <v-icon v-else size="48" color="grey-lighten-1">mdi-account-circle</v-icon>
            </v-avatar>
            <v-btn icon size="small" color="primary" class="avatar-edit-btn" @click="$refs.fileInput.click()">
              <v-icon size="16">mdi-pencil</v-icon>
            </v-btn>
            <input ref="fileInput" type="file" accept="image/*" class="d-none" @change="onFileChange" />
          </div>
          <div>
            <p class="profile-user-name">{{ profile.name }}</p>
            <p class="text-body-2 text-medium-emphasis">{{ profile.email }}</p>
          </div>
        </div>

        <v-divider class="my-4" />

        <!-- Dados pessoais -->
        <v-form ref="form" @submit.prevent="save">
          <p class="section-label">Dados pessoais</p>
          <v-row dense>
            <v-col cols="12">
              <v-text-field
                v-model="profile.name"
                label="Nome completo"
                variant="outlined"
                density="comfortable"
                :rules="[v => !!v || 'Nome é obrigatório']"
                :disabled="saving"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="profile.phone"
                label="Telefone"
                variant="outlined"
                density="comfortable"
                :rules="phoneRules"
                :disabled="saving"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="profile.birth_date"
                label="Data de nascimento"
                type="date"
                variant="outlined"
                density="comfortable"
                :disabled="saving"
              />
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="profile.cpf"
                label="CPF"
                variant="outlined"
                density="comfortable"
                disabled
                hint="O CPF não pode ser alterado"
                persistent-hint
              />
            </v-col>
          </v-row>

          <v-divider class="my-4" />

          <!-- Prioridade no atendimento -->
          <p class="section-label">Prioridade no atendimento</p>
          <p class="text-caption text-medium-emphasis mb-3">
            Pessoas idosas (60+) já têm prioridade automática pela data de nascimento acima, e
            obesidade é calculada automaticamente pelo IMC a partir da altura e peso abaixo.
          </p>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model.number="profile.height_cm"
                label="Altura (cm)"
                type="number"
                variant="outlined"
                density="comfortable"
                :disabled="saving"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model.number="profile.weight_kg"
                label="Peso (kg)"
                type="number"
                step="0.1"
                variant="outlined"
                density="comfortable"
                :disabled="saving"
              />
            </v-col>
            <v-col v-if="bmi" cols="12">
              <p class="text-caption text-medium-emphasis">
                IMC calculado: <strong>{{ bmi }}</strong>
                <span v-if="isObese"> — dentro da faixa de obesidade (prioridade ativada automaticamente)</span>
                <span v-else> — fora da faixa de obesidade</span>
              </p>
            </v-col>

            <v-col cols="12" sm="6">
              <v-switch
                v-model="profile.pcd"
                label="Pessoa com deficiência (inclui TEA)"
                color="success"
                density="comfortable"
                inset
                hide-details
                :disabled="saving"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-switch
                v-model="profile.mobilidade_reduzida"
                label="Mobilidade reduzida"
                color="success"
                density="comfortable"
                inset
                hide-details
                :disabled="saving"
              />
            </v-col>

            <v-col cols="12" sm="6">
              <v-switch
                v-model="profile.gestante"
                label="Gestante"
                color="success"
                density="comfortable"
                inset
                hide-details
                :disabled="saving"
              />
              <v-expand-transition>
                <v-text-field
                  v-if="profile.gestante"
                  v-model="profile.gestante_valid_until"
                  label="Válido até"
                  type="date"
                  variant="outlined"
                  density="comfortable"
                  class="mt-2"
                  :rules="validUntilRules"
                  :disabled="saving"
                />
              </v-expand-transition>
            </v-col>

            <v-col cols="12" sm="6">
              <v-switch
                v-model="profile.lactante"
                label="Lactante"
                color="success"
                density="comfortable"
                inset
                hide-details
                :disabled="saving"
              />
              <v-expand-transition>
                <v-text-field
                  v-if="profile.lactante"
                  v-model="profile.lactante_valid_until"
                  label="Válido até"
                  type="date"
                  variant="outlined"
                  density="comfortable"
                  class="mt-2"
                  :rules="validUntilRules"
                  :disabled="saving"
                />
              </v-expand-transition>
            </v-col>

            <v-col cols="12" sm="6">
              <v-switch
                v-model="profile.crianca_de_colo"
                label="Criança de colo"
                color="success"
                density="comfortable"
                inset
                hide-details
                :disabled="saving"
              />
              <v-expand-transition>
                <v-text-field
                  v-if="profile.crianca_de_colo"
                  v-model="profile.crianca_de_colo_valid_until"
                  label="Válido até"
                  type="date"
                  variant="outlined"
                  density="comfortable"
                  class="mt-2"
                  :rules="validUntilRules"
                  :disabled="saving"
                />
              </v-expand-transition>
            </v-col>
          </v-row>

          <v-divider class="my-4" />

          <!-- Notificações -->
          <p class="section-label">Notificações</p>
          <v-row dense>
            <v-col cols="12">
              <v-switch
                v-model="profile.sms_notifications_enabled"
                label="Avisar por SMS quando eu for chamado"
                color="success"
                density="comfortable"
                inset
                hide-details
                :disabled="saving"
              />
              <p v-if="profile.sms_notifications_enabled" class="text-caption text-medium-emphasis mt-1">
                Telefone obrigatório para receber o aviso.
              </p>
            </v-col>
          </v-row>

          <v-divider class="my-4" />

          <!-- E-mail -->
          <p class="section-label">E-mail de acesso</p>
          <v-row dense>
            <v-col cols="12">
              <v-text-field
                v-model="profile.email"
                label="E-mail"
                type="email"
                variant="outlined"
                density="comfortable"
                :rules="[v => !!v || 'E-mail é obrigatório', v => /.+@.+\..+/.test(v) || 'E-mail inválido']"
                :disabled="saving"
              />
            </v-col>
          </v-row>

          <v-divider class="my-4" />

          <!-- Alterar senha -->
          <p class="section-label">Alterar senha</p>
          <v-row dense>
            <v-col cols="12">
              <v-text-field
                v-model="passwords.new"
                label="Nova senha"
                type="password"
                variant="outlined"
                density="comfortable"
                hint="Deixe em branco para manter a senha atual"
                persistent-hint
                :rules="[v => !v || v.length >= 6 || 'Mínimo 6 caracteres']"
                :disabled="saving"
                autocomplete="new-password"
              />
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="passwords.confirmation"
                label="Confirmar nova senha"
                type="password"
                variant="outlined"
                density="comfortable"
                :rules="[v => !passwords.new || v === passwords.new || 'As senhas não conferem']"
                :disabled="saving"
                autocomplete="new-password"
              />
            </v-col>
          </v-row>

          <!-- Senha atual — aparece quando e-mail ou senha são alterados -->
          <v-expand-transition>
            <div v-if="requiresCurrentPassword" class="current-password-box mt-3">
              <v-icon size="16" color="warning" class="mr-1">mdi-lock-outline</v-icon>
              <span class="text-body-2 text-medium-emphasis">Para alterar e-mail ou senha, confirme sua senha atual</span>
              <v-text-field
                v-model="passwords.current"
                label="Senha atual"
                type="password"
                variant="outlined"
                density="comfortable"
                class="mt-2"
                :rules="requiresCurrentPassword ? [v => !!v || 'Informe sua senha atual'] : []"
                :disabled="saving"
                autocomplete="current-password"
              />
            </div>
          </v-expand-transition>

          <v-alert v-if="errorMsg" type="error" class="mt-3 mb-1" density="compact" rounded="lg">
            {{ errorMsg }}
          </v-alert>
          <v-alert v-if="successMsg" type="success" class="mt-3 mb-1" density="compact" rounded="lg">
            {{ successMsg }}
          </v-alert>

          <div class="mt-4">
            <v-btn type="submit" color="primary" variant="flat" :loading="saving" block>
              Salvar alterações
            </v-btn>
          </div>
        </v-form>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from "vue"
import { apiFetch } from "../../composables/useApi"

const profile = ref({
  name: "", email: "", phone: "", birth_date: "", cpf: "", avatar_url: null,
  pcd: false, mobilidade_reduzida: false,
  height_cm: null, weight_kg: null,
  gestante: false, gestante_valid_until: "",
  lactante: false, lactante_valid_until: "",
  crianca_de_colo: false, crianca_de_colo_valid_until: "",
  sms_notifications_enabled: false,
})
const originalEmail = ref("")
const avatarPreview = ref(null)
const avatarFile = ref(null)
const saving = ref(false)
const errorMsg = ref("")
const successMsg = ref("")
const form = ref(null)
const passwords = ref({ new: "", confirmation: "", current: "" })

const emailChanged = computed(() => profile.value.email !== originalEmail.value)
const requiresCurrentPassword = computed(() => emailChanged.value || !!passwords.value.new)

// IMC = peso (kg) / altura (m)² — mesma fórmula do backend (User#bmi), só
// para feedback imediato; quem decide de fato é sempre o servidor.
const OBESITY_BMI_THRESHOLD = 30
const bmi = computed(() => {
  const height = Number(profile.value.height_cm)
  const weight = Number(profile.value.weight_kg)
  if (!height || !weight) return null

  const heightM = height / 100
  return Math.round((weight / heightM ** 2) * 10) / 10
})
const isObese = computed(() => bmi.value !== null && bmi.value >= OBESITY_BMI_THRESHOLD)

const todayIso = new Date().toISOString().slice(0, 10)
const validUntilRules = [
  (v) => !!v || "Informe até quando a prioridade vale",
  (v) => !v || v >= todayIso || "Não pode ser uma data no passado",
]

// Telefone só é obrigatório se o aviso por SMS estiver ativado — mesma
// regra validada no backend (User#phone), aqui só para feedback imediato.
const phoneRules = computed(() => [
  (v) => !profile.value.sms_notifications_enabled || !!v || "Obrigatório para receber o aviso por SMS",
])

// Limpa a data de validade quando a condição é desmarcada
watch(() => profile.value.gestante, (v) => { if (!v) profile.value.gestante_valid_until = "" })
watch(() => profile.value.lactante, (v) => { if (!v) profile.value.lactante_valid_until = "" })
watch(() => profile.value.crianca_de_colo, (v) => { if (!v) profile.value.crianca_de_colo_valid_until = "" })

const SCROLL_TARGETS = [
  () => document.documentElement,
  () => document.body,
  () => document.getElementById("patient-app"),
  () => document.querySelector(".v-application"),
  () => document.querySelector(".v-main"),
  () => document.querySelector(".v-main__wrap"),
]

function enableScroll() {
  SCROLL_TARGETS.forEach(fn => {
    const el = fn()
    if (!el) return
    el.style.setProperty("overflow-y", "auto", "important")
    el.style.setProperty("height", "auto", "important")
  })
}

function disableScroll() {
  SCROLL_TARGETS.forEach(fn => {
    const el = fn()
    if (!el) return
    el.style.removeProperty("overflow-y")
    el.style.removeProperty("height")
  })
}

onMounted(async () => {
  enableScroll()
  const data = await apiFetch("/api/profile")
  profile.value = { ...data }
  originalEmail.value = data.email
})

onUnmounted(() => {
  disableScroll()
})

function onFileChange(e) {
  const file = e.target.files[0]
  if (!file) return
  avatarFile.value = file
  avatarPreview.value = URL.createObjectURL(file)
}

async function save() {
  const { valid } = await form.value.validate()
  if (!valid) return

  saving.value = true
  errorMsg.value = ""
  successMsg.value = ""

  try {
    const formData = new FormData()
    formData.append("user[name]", profile.value.name)
    formData.append("user[phone]", profile.value.phone || "")
    formData.append("user[birth_date]", profile.value.birth_date || "")
    formData.append("user[email]", profile.value.email)
    formData.append("user[pcd]", profile.value.pcd ? "1" : "0")
    formData.append("user[height_cm]", profile.value.height_cm || "")
    formData.append("user[weight_kg]", profile.value.weight_kg || "")
    formData.append("user[mobilidade_reduzida]", profile.value.mobilidade_reduzida ? "1" : "0")
    formData.append("user[gestante]", profile.value.gestante ? "1" : "0")
    formData.append("user[gestante_valid_until]", profile.value.gestante_valid_until || "")
    formData.append("user[lactante]", profile.value.lactante ? "1" : "0")
    formData.append("user[lactante_valid_until]", profile.value.lactante_valid_until || "")
    formData.append("user[crianca_de_colo]", profile.value.crianca_de_colo ? "1" : "0")
    formData.append("user[crianca_de_colo_valid_until]", profile.value.crianca_de_colo_valid_until || "")
    formData.append("user[sms_notifications_enabled]", profile.value.sms_notifications_enabled ? "1" : "0")
    if (avatarFile.value) formData.append("user[avatar]", avatarFile.value)
    if (passwords.value.new) {
      formData.append("user[password]", passwords.value.new)
      formData.append("user[password_confirmation]", passwords.value.confirmation)
    }
    if (requiresCurrentPassword.value) {
      formData.append("user[current_password]", passwords.value.current)
    }

    const csrf =
      document.getElementById("patient-app")?.dataset?.csrf ||
      document.querySelector('meta[name="csrf-token"]')?.content || ""

    const res = await fetch("/api/profile", {
      method: "PATCH",
      headers: { "X-CSRF-Token": csrf },
      body: formData,
    })
    const data = await res.json()

    if (data.success) {
      profile.value.avatar_url = data.avatar_url
      profile.value.email = data.email
      originalEmail.value = data.email
      avatarPreview.value = null
      avatarFile.value = null
      passwords.value = { new: "", confirmation: "", current: "" }
      successMsg.value = "Perfil atualizado com sucesso!"
      window.dispatchEvent(new CustomEvent("profile:updated", {
        detail: { name: profile.value.name, avatar_url: data.avatar_url }
      }))
    } else {
      errorMsg.value = data.errors?.join(", ") || "Erro ao salvar."
    }
  } catch {
    errorMsg.value = "Erro ao salvar. Tente novamente."
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.profile-container {
  padding-top: 32px;
  padding-bottom: 32px;
}

.profile-page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #2d3748;
  margin-bottom: 20px;
}

.profile-user-name {
  font-size: 1.1rem;
  font-weight: 600;
  color: #2d3748;
  margin-bottom: 2px;
}

.profile-header {
  display: flex;
  align-items: center;
  gap: 20px;
  margin-bottom: 4px;
}

.avatar-wrapper {
  position: relative;
  flex-shrink: 0;
}

.avatar-preview {
  border: 3px solid #e2e8f0;
}

.avatar-edit-btn {
  position: absolute;
  bottom: 0;
  right: 0;
}

.section-label {
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #718096;
  margin-bottom: 12px;
}


.current-password-box {
  background: #fffbeb;
  border: 1px solid #f6e05e;
  border-radius: 8px;
  padding: 12px 14px 4px;
}
</style>
