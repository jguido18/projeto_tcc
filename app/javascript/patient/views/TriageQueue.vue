<template>
  <v-container class="queue-page py-6" fluid>
    <v-row justify="center" align="stretch" class="queue-page__row">
      <v-col cols="12" sm="10" md="4" lg="3">
        <v-card rounded="xl" elevation="4" class="request-card pa-5">
          <div class="request-card__ticket-label">SUA SENHA</div>
          <div class="request-card__ticket-number">{{ entry?.ticket_number || "-" }}</div>

          <div class="request-card__urgency">
            <div
              class="request-card__urgency-ring"
              :style="{ borderColor: store.urgencyColor, boxShadow: `0 0 0 8px ${store.urgencyColor}22` }"
            >
              <v-icon size="24" :color="store.urgencyColor">{{ urgencyIcon }}</v-icon>
            </div>
            <div class="request-card__urgency-text" :style="{ color: store.urgencyColor }">
              {{ session?.urgency_label || session?.ai_summary && "Classificando..." || "Aguardando" }}
            </div>
          </div>

          <div class="request-card__stats">
            <div class="request-card__stat">
              <div class="request-card__stat-label">Posição</div>
              <div class="request-card__stat-value">
                {{ entry?.queue_position && entry?.status === "waiting" ? `${entry.queue_position}º` : "-" }}
              </div>
            </div>
            <div class="request-card__stat">
              <div class="request-card__stat-label">Espera</div>
              <div class="request-card__stat-value">{{ estimatedWait ? `~${estimatedWait} min` : "-" }}</div>
            </div>
          </div>

          <v-chip :color="statusChipColor" variant="tonal" size="small" class="request-card__status">
            <v-icon start size="12">{{ statusChipIcon }}</v-icon>
            {{ statusChipLabel }}
          </v-chip>

          <div v-if="entry?.status === 'called'" class="request-card__called">
            <v-icon color="success" size="26">mdi-bell-ring</v-icon>
            <div class="request-card__called-title">DIRIJA-SE AO PONTO DE ATENDIMENTO</div>
            <div class="request-card__called-subtitle">A equipe está aguardando você.</div>
          </div>
        </v-card>
      </v-col>

      <v-col cols="12" sm="10" md="7" lg="6">
        <v-card rounded="xl" elevation="4" class="board-card">
          <div class="board-card__header">
            <div>
              <div class="board-card__title">Fila de Atendimento</div>
              <div class="board-card__subtitle">Acompanhamento em tempo real</div>
            </div>
            <div class="board-card__legend">
              <v-chip
                v-for="level in urgencyLevels"
                :key="level.key"
                :color="level.color"
                size="x-small"
                variant="flat"
                class="text-white"
              >
                {{ level.label }}
              </v-chip>
            </div>
          </div>

          <div class="board-table-head">
            <div class="board-col board-col--priority">PRIORIDADE</div>
            <div class="board-col board-col--name">NOME</div>
            <div class="board-col board-col--wait">ESPERA ESTIMADA</div>
          </div>

          <div v-if="queueRows.length === 0" class="board-empty">Fila vazia</div>

          <div
            v-for="row in queueRows"
            :key="row.id"
            class="board-row"
            :class="{ 'board-row--mine': row.isMine }"
          >
            <div class="board-col board-col--priority">
              <span class="urgency-dot" :style="{ background: urgencyColor(row.urgency_level) }"></span>
              <span :style="{ color: urgencyColor(row.urgency_level) }">{{ urgencyLabel(row.urgency_level) }}</span>
            </div>
            <div class="board-col board-col--name">{{ row.masked_name }}</div>
            <div class="board-col board-col--wait">~{{ row.estimated_wait }} min</div>
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

const urgencyLevels = computed(() => {
  const levels = store.session?.urgency_levels || []
  return [...levels].sort((a, b) => Number(a.weight) - Number(b.weight))
})

function urgencyColor(level) {
  return store.urgencyMap[level]?.color || "#A0AEC0"
}

function urgencyLabel(level) {
  return store.urgencyMap[level]?.label || "Sem classificação"
}

// Tempo estimado por nível de urgência (em minutos)
const WAIT_TIMES = computed(() => {
  const levels = urgencyLevels.value
  return levels.reduce((acc, level) => {
    acc[level.key] = Math.max((Number(level.weight) - 1) * 20, 0)
    return acc
  }, {})
})

const estimatedWait = computed(() => {
  const level = entry.value?.urgency_level || session.value?.urgency_level
  return WAIT_TIMES.value[level] ?? null
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
  if (s === "awaiting_validation") return "Aguardando validação da equipe"
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
      masked_name:    maskName(data.name || "Solicitante"),
      estimated_wait: WAIT_TIMES.value[e.urgency_level] ?? "?",
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
  await store.fetchStatus()
  await loadQueue()
  if (session.value?.id) {
    unsubscribe = useQueueChannel(session.value.id)
  }
})

onUnmounted(() => unsubscribe?.())
</script>

<style scoped>
.queue-page {
  background:
    radial-gradient(1200px 350px at 15% -15%, rgba(49, 130, 206, 0.16), transparent 55%),
    radial-gradient(900px 320px at 90% 0%, rgba(66, 153, 225, 0.14), transparent 60%),
    #eef3f9;
  min-height: calc(100vh - 56px);
}

.queue-page__row {
  max-width: 1180px;
  margin: 0 auto;
}

.request-card {
  background: linear-gradient(165deg, #10213e 0%, #18345f 100%);
  color: #fff;
  height: 100%;
  border: 1px solid rgba(255, 255, 255, 0.12);
}

.request-card__ticket-label {
  font-size: 0.72rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: #c8daee;
}

.request-card__ticket-number {
  margin-top: 0.15rem;
  font-size: 2.1rem;
  font-weight: 900;
  letter-spacing: 0.12em;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
}

.request-card__urgency {
  margin-top: 1rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.6rem;
}

.request-card__urgency-ring {
  width: 64px;
  height: 64px;
  border-radius: 999px;
  border: 3px solid;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.08);
}

.request-card__urgency-text {
  font-size: 1.05rem;
  font-weight: 700;
}

.request-card__stats {
  margin-top: 1.1rem;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
}

.request-card__stat {
  padding: 0.7rem;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.09);
  border: 1px solid rgba(255, 255, 255, 0.16);
}

.request-card__stat-label {
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: #c8daee;
}

.request-card__stat-value {
  margin-top: 0.18rem;
  font-size: 1.1rem;
  font-weight: 800;
}

.request-card__status {
  margin-top: 0.95rem;
}

.request-card__called {
  margin-top: 0.9rem;
  border-radius: 12px;
  padding: 0.9rem;
  background: rgba(56, 161, 105, 0.18);
  border: 1px solid rgba(56, 161, 105, 0.55);
  text-align: center;
}

.request-card__called-title {
  margin-top: 0.4rem;
  font-weight: 800;
  color: #81e6b5;
  font-size: 1rem;
}

.request-card__called-subtitle {
  margin-top: 0.2rem;
  color: #e6fffa;
  font-size: 0.82rem;
}

.board-card {
  overflow: hidden;
  border: 1px solid #d9e3f0;
  background: #fff;
}

.board-card__header {
  display: flex;
  gap: 1rem;
  align-items: flex-start;
  justify-content: space-between;
  padding: 0.95rem 1rem;
  border-bottom: 1px solid #e7eef8;
  background: linear-gradient(180deg, #f8fbff 0%, #f0f6ff 100%);
}

.board-card__title {
  font-size: 1.08rem;
  font-weight: 800;
  color: #1f3658;
}

.board-card__subtitle {
  margin-top: 0.1rem;
  font-size: 0.8rem;
  color: #6b7f99;
}

.board-card__legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  justify-content: flex-end;
}

.board-table-head,
.board-row {
  display: flex;
}

.board-table-head {
  padding: 0.55rem 1rem;
  border-bottom: 1px solid #e7eef8;
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: #6b7f99;
  background: #f8fbff;
}

.board-row {
  padding: 0.85rem 1rem;
  align-items: center;
  border-bottom: 1px solid #edf2f9;
  color: #35506f;
  font-size: 0.92rem;
}

.board-row--mine {
  background: linear-gradient(90deg, rgba(49, 130, 206, 0.11) 0%, rgba(49, 130, 206, 0.04) 100%);
}

.board-col {
  display: flex;
  align-items: center;
  gap: 0.45rem;
}

.board-col--priority {
  flex: 1.2;
  font-weight: 700;
}

.board-col--name {
  flex: 2;
  color: #2d4a6b;
  font-weight: 600;
}

.board-col--wait {
  flex: 1.2;
  color: #6b7f99;
}

.board-empty {
  padding: 2rem 1rem;
  text-align: center;
  color: #6b7f99;
}

.urgency-dot {
  width: 9px;
  height: 9px;
  border-radius: 999px;
  display: inline-block;
  flex-shrink: 0;
}

@media (max-width: 960px) {
  .request-card__ticket-number {
    font-size: 1.8rem;
  }

  .board-card__header {
    flex-direction: column;
  }

  .board-card__legend {
    justify-content: flex-start;
  }
}

@media (max-width: 640px) {
  .board-table-head,
  .board-row {
    font-size: 0.82rem;
  }

  .board-col--wait {
    justify-content: flex-end;
  }
}
</style>
