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

          <div
            v-if="showQuickReplies"
            class="quick-replies px-3 pt-3 pb-2"
          >
            <div class="quick-replies__label">Respostas rápidas</div>
            <div class="quick-replies__list mt-2">
              <v-btn
                v-for="reply in quickReplies"
                :key="reply"
                class="quick-reply-btn"
                color="primary"
                variant="tonal"
                size="small"
                :disabled="store.sending || isAwaitingValidation"
                @click="sendQuickReply(reply)"
              >
                {{ reply }}
              </v-btn>
            </div>
          </div>

          <!-- Preview do arquivo selecionado -->
          <div v-if="selectedFile" class="file-preview px-3 pt-2 pb-1">
            <v-chip
              closable
              :color="fileValidationColor"
              variant="tonal"
              size="small"
              class="file-chip"
              @click:close="clearFile"
            >
              <v-icon start size="14">{{ fileTypeIcon }}</v-icon>
              {{ selectedFile.name }}
              <v-icon v-if="isValidatingFile" end size="14" class="spinning">mdi-loading</v-icon>
              <v-icon v-else-if="fileValidationStatus === 'valid'"   end size="14">mdi-check-circle</v-icon>
              <v-icon v-else-if="fileValidationStatus === 'invalid'" end size="14">mdi-alert-circle</v-icon>
            </v-chip>
            <div v-if="fileValidationSummary" class="file-validation-summary mt-1">
              {{ fileValidationSummary }}
            </div>
          </div>

          <!-- Campo de input -->
          <div class="chat-input pa-3">
            <!-- Input de arquivo oculto -->
            <input
              ref="fileInputEl"
              type="file"
              accept="image/jpeg,image/png,image/gif,image/webp,application/pdf"
              class="d-none"
              @change="onFileSelected"
            />

            <v-text-field
              v-model="inputText"
              placeholder="Digite sua resposta ou anexe um documento..."
              variant="outlined"
              rounded="pill"
              density="compact"
              hide-details
              :disabled="store.sending || isAwaitingValidation"
              @keydown.enter.prevent="sendMessage"
            >
              <template #prepend-inner>
                <v-btn
                  icon
                  size="x-small"
                  variant="text"
                  :color="selectedFile ? 'primary' : 'grey'"
                  :disabled="store.sending || isAwaitingValidation"
                  title="Anexar documento"
                  @click="fileInputEl.click()"
                >
                  <v-icon size="18">mdi-paperclip</v-icon>
                </v-btn>
              </template>
              <template #append-inner>
                <v-btn
                  :disabled="(!inputText.trim() && !selectedFile) || store.sending || isAwaitingValidation"
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
import { useTriageStore } from "../../stores/triage"
import { useTriageChannel } from "../../composables/useCable"

const store       = useTriageStore()
const chatEl      = ref(null)
const inputText   = ref("")
const fileInputEl = ref(null)
const selectedFile = ref(null)
const pendingDocumentId = ref(null)
let unsubscribe   = null

// ── Document file helpers ──────────────────────────────────────────────────

const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp", "application/pdf"]
const MAX_SIZE      = 10 * 1024 * 1024 // 10 MB

function onFileSelected(event) {
  const file = event.target.files?.[0]
  if (!file) return
  if (!ALLOWED_TYPES.includes(file.type)) {
    alert("Tipo de arquivo não permitido. Use JPG, PNG, WebP ou PDF.")
    fileInputEl.value.value = ""
    return
  }
  if (file.size > MAX_SIZE) {
    alert("Arquivo muito grande. O limite é 10 MB.")
    fileInputEl.value.value = ""
    return
  }
  selectedFile.value = file
  pendingDocumentId.value = null
}

function clearFile() {
  selectedFile.value = null
  pendingDocumentId.value = null
  if (fileInputEl.value) fileInputEl.value.value = ""
}

const fileTypeIcon = computed(() => {
  if (!selectedFile.value) return "mdi-file"
  if (selectedFile.value.type.startsWith("image/")) return "mdi-image"
  return "mdi-file-pdf-box"
})

const isValidatingFile = computed(() => {
  if (!pendingDocumentId.value) return false
  const v = store.documentValidations[pendingDocumentId.value]
  return !v
})

const fileValidationStatus = computed(() => {
  if (!pendingDocumentId.value) return null
  return store.documentValidations[pendingDocumentId.value]?.status || null
})

const fileValidationSummary = computed(() => {
  if (!pendingDocumentId.value) return null
  return store.documentValidations[pendingDocumentId.value]?.summary || null
})

const fileValidationColor = computed(() => {
  switch (fileValidationStatus.value) {
    case "valid":     return "success"
    case "invalid":   return "error"
    case "uncertain": return "warning"
    default:          return "primary"
  }
})

const isAwaitingValidation = computed(() =>
  ["awaiting_validation", "validated", "in_queue", "in_attendance", "completed"]
    .includes(store.session?.status)
)

const statusLabel = computed(() =>
  isAwaitingValidation.value ? "Aguardando validação da equipe" : "Em triagem"
)

const lastAiMessage = computed(() => {
  for (let i = store.messages.length - 1; i >= 0; i -= 1) {
    const msg = store.messages[i]
    if (msg.sender === "ai" && msg.content) return msg.content
  }
  return ""
})

function normalizeText(text = "") {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
}

function uniqueReplies(list) {
  return [...new Set(list)].slice(0, 5)
}

function extractLastQuestion(text = "") {
  const normalized = normalizeText(text)
  const sentences = normalized
    .split(/[.!\n]/)
    .map((part) => part.trim())
    .filter(Boolean)

  for (let i = sentences.length - 1; i >= 0; i -= 1) {
    const sentence = sentences[i]
    if (sentence.includes("?")) return sentence
  }

  return sentences.at(-1) || normalized
}

function matchCount(text, patterns) {
  return patterns.reduce((count, pattern) => (pattern.test(text) ? count + 1 : count), 0)
}

const INTENT_RULES = [
  {
    key: "medication",
    priority: 120,
    patterns: [/tomou/, /medicamento/, /remedio/, /aliviar/, /se sim, qual/],
    replies: ["Nao tomei remedio", "Tomei e melhorou", "Tomei e nao melhorou", "Tomei, mas nao lembro o nome"],
  },
  {
    key: "pain_pattern",
    priority: 110,
    patterns: [/constante/, /vem e vai/, /vai e volta/, /intermitente/, /o tempo todo/],
    replies: ["Constante", "Vem e vai", "Piorou nas ultimas horas", "Nao sei informar"],
  },
  {
    key: "pain_intensity",
    priority: 100,
    patterns: [
      /\bde\s*0\s*a\s*10\b/,
      /escala/,
      /intensidade.*dor/,
      /dor.*intensidade/,
      /leve.*moderad.*intens/,
      /intens.*moderad.*leve/,
      /dor.*leve/,
      /dor.*moderad/,
      /dor.*intens/,
    ],
    replies: ["0 a 3 (leve)", "4 a 7 (moderada)", "8 a 10 (forte)", "Sem dor"],
  },
  {
    key: "shortness_of_breath",
    priority: 95,
    patterns: [/falta de ar/, /dificuldade para respirar/, /consegue respirar/, /respiracao/],
    replies: ["Sem falta de ar", "Falta de ar leve", "Falta de ar intensa", "Piorando agora"],
  },
  {
    key: "fever",
    priority: 90,
    patterns: [/febre/, /temperatura/, /termometro/],
    replies: ["Sem febre", "Febre baixa", "Febre alta", "Nao medi a temperatura"],
  },
  {
    key: "symptom_duration",
    priority: 85,
    patterns: [/ha quanto tempo/, /desde quando/, /quando comecou/, /quanto tempo/],
    replies: ["Comecou hoje", "Ha 1 a 2 dias", "Ha mais de 3 dias", "Piorou hoje"],
  },
  {
    key: "pain_location",
    priority: 80,
    patterns: [/onde doi/, /em qual local/, /em qual regiao/, /onde esta a dor/, /local da dor/],
    replies: ["Cabeca", "Peito", "Abdomen", "Garganta", "Outro local"],
  },
  {
    key: "allergy",
    priority: 75,
    patterns: [/alerg/],
    replies: ["Nao tenho alergias", "Alergia a medicamento", "Alergia alimentar", "Nao sei informar"],
  },
  {
    key: "nausea",
    priority: 70,
    patterns: [/vomito/, /nausea/, /enjoo/],
    replies: ["Sem vomito", "Nausea leve", "Vomitei 1 vez", "Vomitos frequentes"],
  },
  {
    key: "bleeding",
    priority: 65,
    patterns: [/sangramento/, /sangue/],
    replies: ["Sem sangramento", "Sangramento leve", "Sangramento intenso", "Sangue nas fezes/urina"],
  },
  {
    key: "dizziness",
    priority: 60,
    patterns: [/tontura/, /desmaio/, /desmaiou/],
    replies: ["Sem tontura", "Tontura leve", "Tontura forte", "Quase desmaiei"],
  },
  {
    key: "age_group",
    priority: 55,
    patterns: [/qual sua idade/, /quantos anos/, /idade/],
    replies: ["Menos de 18", "18 a 59", "60 ou mais", "Prefiro nao informar"],
  },
]

function bestIntentReplies(text) {
  let bestRule = null
  let bestScore = 0

  INTENT_RULES.forEach((rule) => {
    const hits = matchCount(text, rule.patterns)
    if (hits === 0) return

    const score = rule.priority + hits * 10
    if (score > bestScore) {
      bestScore = score
      bestRule = rule
    }
  })

  return bestRule?.replies || null
}

function buildDynamicReplies(message) {
  const text = extractLastQuestion(message)
  const genericReplies = ["Sim", "Nao", "Nao sei informar", "Pode repetir a pergunta?"]

  if (!text) {
    return genericReplies
  }

  const intentReplies = bestIntentReplies(text)
  if (intentReplies) {
    return uniqueReplies([...intentReplies, "Nao sei informar", "Pode repetir a pergunta?"])
  }

  if (text.includes("?")) {
    return uniqueReplies(genericReplies)
  }

  return uniqueReplies(["Entendi", "Pode repetir a pergunta?", "Nao sei informar", "Prefiro digitar minha resposta"])
}

const quickReplies = computed(() => buildDynamicReplies(lastAiMessage.value))

const showQuickReplies = computed(() =>
  !isAwaitingValidation.value && quickReplies.value.length > 0
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
  const file = selectedFile.value
  if ((!text && !file) || store.sending || isAwaitingValidation.value) return

  inputText.value = ""
  selectedFile.value = null
  if (fileInputEl.value) fileInputEl.value.value = ""

  const data = await store.sendMessage(text || `Segue o documento: ${file?.name || ""}`, file)

  if (data?.document?.id && data.document.is_image) {
    pendingDocumentId.value = data.document.id
  }
}

async function sendQuickReply(reply) {
  if (!reply || store.sending || isAwaitingValidation.value) return
  await store.sendMessage(reply)
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

.quick-replies {
  background: linear-gradient(180deg, #f8fbff 0%, #f3f8fe 100%);
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.quick-replies__label {
  font-size: 0.86rem;
  color: #2d3748;
  font-weight: 700;
  letter-spacing: 0.2px;
}

.quick-replies__list {
  display: flex;
  flex-wrap: nowrap;
  gap: 8px;
  overflow-x: auto;
  overflow-y: hidden;
  padding-bottom: 2px;
  scrollbar-width: thin;
  scrollbar-color: #a0c4e8 transparent;
}

.quick-replies__list::-webkit-scrollbar {
  height: 6px;
}

.quick-replies__list::-webkit-scrollbar-track {
  background: transparent;
}

.quick-replies__list::-webkit-scrollbar-thumb {
  background: #a0c4e8;
  border-radius: 999px;
}

.quick-reply-btn {
  text-transform: none;
  font-weight: 600;
  letter-spacing: 0;
  min-height: 38px;
  border-radius: 999px;
  white-space: nowrap;
  flex: 0 0 auto;
  box-shadow: inset 0 0 0 1px rgba(49, 130, 206, 0.18);
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

/* ── File preview ── */
.file-preview {
  background: #f0f7ff;
  border-top: 1px solid rgba(49, 130, 206, 0.12);
}

.file-chip {
  font-size: 0.8rem;
  max-width: 100%;
}

.file-validation-summary {
  font-size: 0.78rem;
  color: #4a5568;
  padding-left: 4px;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to   { transform: rotate(360deg); }
}

.spinning {
  animation: spin 1s linear infinite;
}
</style>
