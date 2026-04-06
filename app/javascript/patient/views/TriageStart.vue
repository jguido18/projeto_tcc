<template>
  <v-container class="fill-height" fluid>
    <v-row justify="center" align="center">
      <v-col cols="12" sm="8" md="5" lg="4">

        <v-card rounded="xl" elevation="3" class="pa-6">
          <!-- Ícone e título -->
          <div class="text-center mb-6">
            <v-avatar color="primary" size="72" class="mb-4">
              <v-icon size="36" color="white">mdi-account</v-icon>
            </v-avatar>
            <h1 class="text-h5 font-weight-bold text-grey-darken-3">Identificação</h1>
            <p class="text-body-2 text-medium-emphasis mt-1">
              Por favor, identifique-se para iniciar a triagem.
            </p>
          </div>

          <!-- Formulário -->
          <v-form ref="form" @submit.prevent="submit">
            <v-textarea
              v-model="chiefComplaint"
              label="O que está sentindo?"
              placeholder="Descreva brevemente o que está sentindo..."
              rows="3"
              variant="outlined"
              rounded="lg"
              auto-grow
              :rules="[required]"
              :disabled="loading"
              class="mb-4"
            />

            <v-alert
              v-if="error"
              type="error"
              variant="tonal"
              rounded="lg"
              class="mb-4"
              density="compact"
            >
              {{ error }}
            </v-alert>

            <v-btn
              type="submit"
              color="primary"
              block
              size="large"
              rounded="lg"
              :loading="loading"
              prepend-icon="mdi-play-circle"
            >
              Iniciar Triagem
            </v-btn>
          </v-form>
        </v-card>

      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { ref } from "vue"
import { useRouter } from "vue-router"
import { useTriageStore } from "../stores/triage"

const store  = useTriageStore()
const router = useRouter()

const form           = ref(null)
const chiefComplaint = ref("")
const loading        = ref(false)
const error          = ref("")

const required = (v) => !!v?.trim() || "Campo obrigatório"

async function submit() {
  const { valid } = await form.value.validate()
  if (!valid) return

  loading.value = true
  error.value   = ""

  try {
    await store.startTriage(chiefComplaint.value.trim())
    router.push("/app/chat")
  } catch (e) {
    error.value = e.message || "Erro ao iniciar triagem."
  } finally {
    loading.value = false
  }
}
</script>
