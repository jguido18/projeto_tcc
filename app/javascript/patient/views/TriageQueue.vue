<template>
  <v-container class="fill-height py-6" fluid>
    <v-row justify="center" align="start">

      <!-- Coluna esquerda: painel do paciente -->
      <v-col cols="12" sm="10" md="4" lg="3">
        <v-card rounded="xl" elevation="3" class="pa-6 text-center" style="background:#1a202c; color:#fff;">

          <!-- Senha -->
          <div class="text-caption text-medium-emphasis mb-1" style="color:#a0aec0; letter-spacing:.1em; text-transform:uppercase;">
            SUA SENHA
          </div>
          <div class="ticket-number mb-4">
            {{ entry?.ticket_number || "—" }}
          </div>

          <!-- Círculo de urgência -->
          <div class="urgency-circle-wrap mb-3">
            <div
              class="urgency-circle"
              :style="{ borderColor: store.urgencyColor, boxShadow: `0 0 24px ${store.urgencyColor}55` }"
            >
              <v-icon size="28" :color="store.urgencyColor">
                {{ urgencyIcon }}
              </v-icon>
            </div>
          </div>

          <!-- Label de urgência -->
          <div class="urgency-label mb-1" :style="{ color: store.urgencyColor }">
            {{ session?.urgency_label || session?.ai_summary && "Classificando..." || "Aguardando" }}
          </div>

          <!-- Tempo estimado -->
          <div v-if="estimatedWait" class="text-caption mb-4" style="color:#a0aec0;">
            Tempo estimado: ~{{ estimatedWait }} min
          </div>

          <v-divider color="grey-darken-3" class="mb-4" />

          <!-- Status da triagem -->
          <v-chip
            :color="statusChipColor"
            variant="tonal"
            size="small"
            class="mb-3"
          >
            <v-icon start size="12">{{ statusChipIcon }}</v-icon>
            {{ statusChipLabel }}
          </v-chip>

          <!-- Posição na fila -->
          <div v-if="entry?.queue_position && entry?.status === 'waiting'" class="queue-position mt-4">
            <div class="text-caption" style="color:#a0aec0;">Sua posição na fila</div>
            <div class="position-number">{{ entry.queue_position }}º</div>
          </div>

          <!-- Chamado agora! -->
          <div v-if="entry?.status === 'called'" class="called-alert mt-4">
            <v-icon color="success" size="32" class="mb-2">mdi-bell-ring</v-icon>
            <div class="text-h6 font-weight-bold text-success">DIRIJA-SE AO CONSULTÓRIO</div>
            <div class="text-caption mt-1" style="color:#a0aec0;">O médico está aguardando você.</div>
          </div>

        </v-card>
      </v-col>

      <!-- Coluna direita: fila geral -->
      <v-col cols="12" sm="10" md="6" lg="5">
        <v-card rounded="xl" elevation="3" style="background:#1e2736; color:#fff; overflow:hidden;">

          <!-- Header da fila -->
          <div class="queue-board-header px-4 py-3">
            <div class="d-flex align-center justify-space-between">
              <span class="text-subtitle-1 font-weight-bold">Chamada Geral</span>
              <div class="d-flex gap-2 flex-wrap">
                <v-chip
                  v-for="(color, level) in URGENCY_COLORS"
                  :key="level"
                  :color="color"
                  size="x-small"
                  variant="flat"
                  class="text-white"
                >
                  {{ URGENCY_LABELS[level] }}
                </v-chip>
              </div>
            </div>
          </div>

          <!-- Cabeçalho da tabela -->
          <div class="queue-table-head px-4 py-2">
            <div class="queue-col queue-col--priority">PRIORIDADE</div>
            <div class="queue-col queue-col--name">NOME</div>
            <div class="queue-col queue-col--wait">ESPERA ESTIMADA</div>
          </div>

          <!-- Linhas da fila -->
          <div v-if="queueRows.length === 0" class="text-center py-8 text-medium-emphasis">
            Fila vazia
          </div>

          <div
            v-for="(row, i) in queueRows"
            :key="row.id"
            class="queue-row px-4 py-3"
            :class="{ 'queue-row--mine': row.isMine, 'queue-row--first': i === 0 }"
          >
            <div class="queue-col queue-col--priority">
              <span
                class="urgency-dot"
                :style="{ background: URGENCY_COLORS[row.urgency_level] }"
              ></span>
              <span :style="{ color: URGENCY_COLORS[row.urgency_level] }">
                {{ URGENCY_LABELS[row.urgency_level] }}
              </span>
            </div>
            <div class="queue-col queue-col--name">{{ row.masked_name }}</div>
            <div class="queue-col queue-col--wait">~{{ row.estimated_wait }} min</div>
          </div>

        </v-card>
      </v-col>

    </v-row>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from "vue"
import { useTriageStore } from "../stores/triage"
import { useQueueChannel } from "../composables/useCable"
import { apiFetch } from "../composables/useApi"

const store = useTriageStore()

const session = computed(() => store.session)
const entry   = computed(() => store.session?.queue_entry)

let unsubscribe = null

// Constantes de urgência
const URGENCY_COLORS = {
  red:    "#E53E3E",
  orange: "#DD6B20",
  yellow: "#D69E2E",
  green:  "#38A169",
  blue:   "#3182CE",
}

const URGENCY_LABELS = {
  red:    "Emergência",
  orange: "Muito Urgente",
  yellow: "Urgente",
  green:  "Pouco Urgente",
  blue:   "Não Urgente",
}

// Tempo estimado por nível de urgência (em minutos)
const WAIT_TIMES = { red: 0, orange: 10, yellow: 30, green: 60, blue: 120 }

const estimatedWait = computed(() => {
  const level = entry.value?.urgency_level || session.value?.urgency_level
  return WAIT_TIMES[level] ?? null
})

const urgencyIcon = computed(() => {
  const level = entry.value?.urgency_level || session.value?.urgency_level
  const icons = {
    red: "mdi-alert-circle", orange: "mdi-alert", yellow: "mdi-clock-alert",
    green: "mdi-check-circle", blue: "mdi-information",
  }
  return icons[level] || "mdi-help-circle-outline"
})

// Status chip
const statusChipColor = computed(() => {
  const s = session.value?.status
  if (s === "awaiting_validation") return "warning"
  if (s === "in_queue") return "info"
  if (s === "in_attendance" || entry.value?.status === "called") return "success"
  return "default"
})

const statusChipIcon = computed(() => {
  const s = session.value?.status
  if (s === "awaiting_validation") return "mdi-clock-outline"
  if (s === "in_queue") return "mdi-format-list-numbered"
  if (s === "in_attendance" || entry.value?.status === "called") return "mdi-bell"
  return "mdi-dots-horizontal"
})

const statusChipLabel = computed(() => {
  const s = session.value?.status
  if (s === "awaiting_validation") return "Aguardando validação da enfermagem"
  if (s === "in_queue") return "Na fila de espera"
  if (entry.value?.status === "called") return "● CHAMANDO AGORA"
  if (s === "in_attendance") return "Em atendimento"
  return "..."
})

// Linhas da fila geral (só mostra waiting + called da mesma session)
const queueRows = ref([])

async function loadQueue() {
  try {
    const data = await apiFetch("/api/triage/status")
    if (!data || data.status === "none") return

    const e = data.queue_entry
    if (!e) return

    queueRows.value = [{
      id:             e.id,
      urgency_level:  e.urgency_level,
      masked_name:    maskName(data.name || "Paciente"),
      estimated_wait: WAIT_TIMES[e.urgency_level] ?? "?",
      isMine:         true,
    }]
  } catch {
    // silencioso
  }
}

function maskName(name) {
  const parts = name.split(" ")
  return parts[0] + (parts.length > 1 ? " " + parts[parts.length - 1].slice(0, 1) + "***" : "")
}

onMounted(async () => {
  if (!store.loaded) await store.fetchStatus()
  await loadQueue()
  if (session.value?.id) {
    unsubscribe = useQueueChannel(session.value.id)
  }
})

onUnmounted(() => unsubscribe?.())
</script>

<style scoped>
.ticket-number {
  font-size: 2.5rem;
  font-weight: 900;
  letter-spacing: .12em;
  color: #fff;
  font-family: monospace;
}

.urgency-circle-wrap {
  display: flex;
  justify-content: center;
}

.urgency-circle {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  border: 3px solid #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255,255,255,0.05);
  transition: border-color 0.4s, box-shadow 0.4s;
}

.urgency-label {
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: .02em;
}

.queue-position { }
.position-number {
  font-size: 2.5rem;
  font-weight: 900;
  color: #fff;
}

.called-alert {
  background: rgba(56,161,105,.15);
  border: 1px solid #38A169;
  border-radius: 12px;
  padding: 1rem;
}

/* Fila geral */
.queue-board-header {
  background: #1e2736;
  border-bottom: 1px solid #2d3748;
}

.queue-table-head {
  display: flex;
  background: #161d2b;
  border-bottom: 1px solid #2d3748;
  font-size: .72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .08em;
  color: #718096;
}

.queue-row {
  display: flex;
  align-items: center;
  border-bottom: 1px solid #2d3748;
  font-size: .9rem;
  transition: background .15s;
}

.queue-row--mine { background: rgba(49,130,206,.1); }
.queue-row--first { font-size: 1rem; }

.queue-col {
  display: flex;
  align-items: center;
  gap: 6px;
}

.queue-col--priority { flex: 1.2; }
.queue-col--name     { flex: 2; color: #e2e8f0; }
.queue-col--wait     { flex: 1.2; color: #a0aec0; font-size: .82rem; }

.urgency-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
</style>
