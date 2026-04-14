<template>
  <div class="triage-start-page">
    <div class="triage-start-card">

      <!-- Decorative top bar -->
      <div class="triage-start-card__topbar"></div>

      <!-- Header -->
      <div class="triage-start-card__header">
        <div class="triage-start-card__icon-wrap">
          <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
            <!-- Nodes flowing into center -->
            <circle cx="5" cy="10" r="3" fill="white" opacity="0.7"/>
            <circle cx="5" cy="22" r="3" fill="white" opacity="0.7"/>
            <circle cx="27" cy="10" r="3" fill="white" opacity="0.7"/>
            <circle cx="27" cy="22" r="3" fill="white" opacity="0.7"/>
            <!-- Lines to center -->
            <line x1="8" y1="10" x2="14" y2="16" stroke="white" stroke-width="1.5" opacity="0.5"/>
            <line x1="8" y1="22" x2="14" y2="16" stroke="white" stroke-width="1.5" opacity="0.5"/>
            <line x1="24" y1="10" x2="18" y2="16" stroke="white" stroke-width="1.5" opacity="0.5"/>
            <line x1="24" y1="22" x2="18" y2="16" stroke="white" stroke-width="1.5" opacity="0.5"/>
            <!-- Central AI node -->
            <circle cx="16" cy="16" r="5" fill="white" opacity="0.9"/>
            <circle cx="16" cy="16" r="2.5" fill="#3182CE"/>
          </svg>
        </div>
        <div>
          <h1 class="triage-start-card__title">Início da Triagem</h1>
          <p class="triage-start-card__subtitle">
            Descreva sua necessidade e nossa IA irá guiá-lo pelo processo.
          </p>
        </div>
      </div>

      <!-- Info chips -->
      <div class="triage-start-card__chips">
        <span class="triage-start-chip">
          <svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor"><path d="M8 .5a7.5 7.5 0 1 0 0 15A7.5 7.5 0 0 0 8 .5Zm3.28 5.78-4 4a.75.75 0 0 1-1.06 0l-2-2a.75.75 0 0 1 1.06-1.06L6.75 8.69l3.47-3.47a.75.75 0 0 1 1.06 1.06Z"/></svg>
          Atendimento inteligente
        </span>
        <span class="triage-start-chip">
          <svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor"><path d="M8 .5a7.5 7.5 0 1 0 0 15A7.5 7.5 0 0 0 8 .5Zm3.28 5.78-4 4a.75.75 0 0 1-1.06 0l-2-2a.75.75 0 0 1 1.06-1.06L6.75 8.69l3.47-3.47a.75.75 0 0 1 1.06 1.06Z"/></svg>
          Classificação automática
        </span>
        <span class="triage-start-chip">
          <svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor"><path d="M8 .5a7.5 7.5 0 1 0 0 15A7.5 7.5 0 0 0 8 .5Zm3.28 5.78-4 4a.75.75 0 0 1-1.06 0l-2-2a.75.75 0 0 1 1.06-1.06L6.75 8.69l3.47-3.47a.75.75 0 0 1 1.06 1.06Z"/></svg>
          Fila priorizada
        </span>
      </div>

      <!-- Form -->
      <v-form ref="form" class="triage-start-card__form" @submit.prevent="submit">
        <div class="triage-start-field">
          <label class="triage-start-label" for="initial-demand">
            Qual é a sua necessidade inicial?
          </label>
          <v-textarea
            id="initial-demand"
            v-model="initialDemand"
            placeholder="Descreva brevemente o motivo do atendimento..."
            rows="3"
            variant="outlined"
            rounded="lg"
            auto-grow
            :rules="[required]"
            :disabled="loading"
            class="triage-start-textarea"
            hide-details="auto"
          />
          <p v-if="store.hintExample" class="triage-start-hint">
            {{ store.hintExample }}
          </p>
        </div>

        <v-alert
          v-if="error"
          type="error"
          variant="tonal"
          rounded="lg"
          density="compact"
          class="mt-1"
        >
          {{ error }}
        </v-alert>

        <v-btn
          type="submit"
          block
          size="large"
          rounded="lg"
          :loading="loading"
          class="triage-start-submit"
          elevation="0"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="margin-right:8px;">
            <polygon points="5 3 19 12 5 21 5 3"/>
          </svg>
          Iniciar Triagem
        </v-btn>
      </v-form>

    </div>
  </div>
</template>

<script setup>
import { ref } from "vue"
import { useRouter } from "vue-router"
import { useTriageStore } from "../../stores/triage"

const store  = useTriageStore()
const router = useRouter()

const form           = ref(null)
const initialDemand  = ref("")
const loading        = ref(false)
const error          = ref("")

const required = (v) => !!v?.trim() || "Campo obrigatório"

async function submit() {
  const { valid } = await form.value.validate()
  if (!valid) return

  loading.value = true
  error.value   = ""

  try {
    await store.startTriage(initialDemand.value.trim())
    router.push("/app/chat")
  } catch (e) {
    error.value = e.message || "Erro ao iniciar triagem."
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.triage-start-page {
  height: calc(100vh - 56px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem;
  background: linear-gradient(160deg, #ebf8ff 0%, #f7fafc 50%, #f0fff4 100%);
}

.triage-start-card {
  width: 100%;
  max-width: 520px;
  background: #fff;
  border-radius: 20px;
  box-shadow: 0 8px 40px rgba(49, 130, 206, 0.12), 0 2px 10px rgba(0,0,0,0.06);
  overflow: hidden;
  border: 1px solid #e2e8f0;
}

.triage-start-card__topbar {
  height: 5px;
  background: linear-gradient(90deg, #3182ce, #63b3ed, #38a169);
}

.triage-start-card__header {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.5rem 1.75rem 0;
}

.triage-start-card__icon-wrap {
  width: 56px;
  height: 56px;
  border-radius: 14px;
  background: linear-gradient(135deg, #3182ce, #2b6cb0);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 4px 14px rgba(49, 130, 206, 0.35);
}

.triage-start-card__title {
  font-size: 1.35rem;
  font-weight: 800;
  color: #1a202c;
  margin: 0 0 0.2rem;
  letter-spacing: -0.02em;
}

.triage-start-card__subtitle {
  font-size: 0.875rem;
  color: #718096;
  margin: 0;
  line-height: 1.45;
}

.triage-start-card__chips {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
  padding: 1rem 1.75rem 0;
}

.triage-start-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  background: #ebf8ff;
  color: #2b6cb0;
  border: 1px solid #bee3f8;
  border-radius: 999px;
  padding: 0.2rem 0.65rem;
  font-size: 0.75rem;
  font-weight: 600;
}

.triage-start-card__form {
  padding: 1.25rem 1.75rem 1.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.triage-start-field {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.triage-start-label {
  font-size: 0.875rem;
  font-weight: 700;
  color: #2d3748;
}

.triage-start-hint {
  font-size: 0.75rem;
  color: #a0aec0;
  margin: 0;
}

.triage-start-submit {
  background: linear-gradient(135deg, #3182ce, #2b6cb0) !important;
  color: #fff !important;
  font-weight: 700 !important;
  font-size: 0.975rem !important;
  letter-spacing: 0.01em !important;
  height: 50px !important;
}

.triage-start-submit:hover {
  background: linear-gradient(135deg, #2b6cb0, #2c5282) !important;
}
</style>
