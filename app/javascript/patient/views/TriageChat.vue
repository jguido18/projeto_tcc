<template>
  <div class="chat-page">
    <div class="chat-col">

        <!-- Card do chat -->
        <v-card rounded="xl" elevation="3" class="chat-card">

          <!-- Header -->
          <v-card-title class="chat-header px-4 py-3">
            <div class="d-flex align-center justify-space-between">
              <div class="d-flex align-center gap-2">
                <v-avatar color="primary" size="36">
                  <v-icon size="20" color="white">mdi-robot</v-icon>
                </v-avatar>
                <div>
                  <div class="text-subtitle-1 font-weight-bold">Assistente de Triagem</div>
                  <div class="text-caption text-medium-emphasis">{{ statusLabel }}</div>
                </div>
              </div>

              <!-- Badge de status -->
              <v-chip
                :color="isAwaitingValidation ? 'warning' : 'success'"
                size="small"
                variant="tonal"
              >
                <v-icon start size="12">
                  {{ isAwaitingValidation ? "mdi-clock-outline" : "mdi-circle" }}
                </v-icon>
                {{ isAwaitingValidation ? "Aguardando validação" : "Em triagem" }}
              </v-chip>

              <v-btn
                v-if="!isAwaitingValidation"
                color="warning"
                variant="flat"
                size="small"
                :loading="store.sending"
                :disabled="store.sending"
                @click="finishTriage"
              >
                Finalizar triagem
              </v-btn>
            </div>
          </v-card-title>

          <v-divider />

          <!-- Área de mensagens -->
          <div
            ref="chatEl"
            class="chat-messages pa-4"
          >
            <div
              v-for="msg in store.messages"
              :key="msg.id"
              class="message-row"
              :class="msg.sender === 'user' ? 'message-row--user' : 'message-row--ai'"
            >
              <!-- Avatar da IA -->
              <v-avatar
                v-if="msg.sender === 'ai'"
                color="primary"
                size="28"
                class="flex-shrink-0"
              >
                <v-icon size="16" color="white">mdi-robot</v-icon>
              </v-avatar>

              <!-- Balão -->
              <div
                class="message-bubble"
                :class="msg.sender === 'user' ? 'message-bubble--user' : 'message-bubble--ai'"
              >
                <span v-if="msg.pending" class="pending-dots">
                  <span></span><span></span><span></span>
                </span>
                <span v-else>{{ msg.content }}</span>
              </div>

              <!-- Avatar do paciente -->
              <v-avatar
                v-if="msg.sender === 'user'"
                color="secondary"
                size="28"
                class="flex-shrink-0"
              >
                <v-icon size="16" color="white">mdi-account</v-icon>
              </v-avatar>
            </div>

            <!-- Indicador de digitação da IA -->
            <div v-if="store.sending" class="message-row message-row--ai">
              <v-avatar color="primary" size="28" class="flex-shrink-0">
                <v-icon size="16" color="white">mdi-robot</v-icon>
              </v-avatar>
              <div class="message-bubble message-bubble--ai">
                <span class="pending-dots">
                  <span></span><span></span><span></span>
                </span>
              </div>
            </div>
          </div>

          <v-divider />

          <!-- Campo de input -->
          <div class="chat-input pa-3">
            <v-text-field
              v-model="inputText"
              placeholder="Digite sua resposta..."
              variant="outlined"
              rounded="pill"
              density="compact"
              hide-details
              :disabled="store.sending || isAwaitingValidation"
              @keydown.enter.prevent="sendMessage"
            >
              <template #append-inner>
                <v-btn
                  :disabled="!inputText.trim() || store.sending || isAwaitingValidation"
                  icon
                  size="small"
                  color="primary"
                  variant="flat"
                  rounded="pill"
                  @click="sendMessage"
                >
                  <v-icon size="18">mdi-send</v-icon>
                </v-btn>
              </template>
            </v-text-field>
          </div>
        </v-card>

    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from "vue"
import { useTriageStore } from "../stores/triage"
import { useTriageChannel } from "../composables/useCable"

const store     = useTriageStore()
const chatEl    = ref(null)
const inputText = ref("")
let unsubscribe = null

const isAwaitingValidation = computed(() =>
  ["awaiting_validation", "validated", "in_queue", "in_attendance", "completed"]
    .includes(store.session?.status)
)

const statusLabel = computed(() =>
  isAwaitingValidation.value ? "Aguardando validação da equipe" : "Em triagem"
)

onMounted(async () => {
  if (store.messages.length === 0) {
    await store.fetchMessages()
  }
  if (store.session?.id) {
    unsubscribe = useTriageChannel(store.session.id)
  }
  scrollBottom()
})

onUnmounted(() => unsubscribe?.())

// Rola para o final sempre que uma nova mensagem chega
watch(() => store.messages.length, () => nextTick(scrollBottom))
watch(() => store.sending, () => nextTick(scrollBottom))

function scrollBottom() {
  if (chatEl.value) {
    chatEl.value.scrollTop = chatEl.value.scrollHeight
  }
}

async function sendMessage() {
  const text = inputText.value.trim()
  if (!text || store.sending || isAwaitingValidation.value) return
  inputText.value = ""
  await store.sendMessage(text)
}

async function finishTriage() {
  if (store.sending || isAwaitingValidation.value) return
  const data = await store.finishTriage()
  if (data?.finished) {
    await store.fetchMessages()
  }
}
</script>

<style scoped>
/* ── Layout externo ── */
.chat-page {
  height: calc(100vh - 56px);
  display: flex;
  align-items: stretch;
  justify-content: center;
  padding: 1rem;
  box-sizing: border-box;
  overflow: hidden;
}

.chat-col {
  width: 100%;
  max-width: 680px;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

/* ── Card ── */
.chat-card {
  display: flex !important;
  flex-direction: column !important;
  flex: 1 !important;
  min-height: 0 !important;
  overflow: hidden !important;
}

/* ── Área de mensagens com scroll ── */
.chat-messages {
  flex: 1;
  overflow-y: auto;
  min-height: 0;
}

.chat-header {
  background: #fff;
}

.message-row {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  margin-bottom: 12px;
}

.message-row--user {
  flex-direction: row-reverse;
}

.message-bubble {
  max-width: 72%;
  padding: 10px 14px;
  border-radius: 18px;
  font-size: 0.9rem;
  line-height: 1.5;
  word-break: break-word;
  white-space: pre-wrap;
}

.message-bubble--ai {
  background: #EBF8FF;
  color: #2D3748;
  border-bottom-left-radius: 4px;
}

.message-bubble--user {
  background: #3182CE;
  color: #fff;
  border-bottom-right-radius: 4px;
}

/* Animação de três pontinhos */
.pending-dots {
  display: inline-flex;
  gap: 4px;
  align-items: center;
  height: 18px;
}

.pending-dots span {
  display: inline-block;
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: currentColor;
  opacity: 0.5;
  animation: bounce 1.2s infinite ease-in-out;
}

.pending-dots span:nth-child(2) { animation-delay: 0.2s; }
.pending-dots span:nth-child(3) { animation-delay: 0.4s; }

@keyframes bounce {
  0%, 80%, 100% { transform: scale(0.7); opacity: 0.4; }
  40%           { transform: scale(1);   opacity: 1;   }
}
</style>
