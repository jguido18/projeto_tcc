<template>
  <div class="queue-layout">

    <!-- ── Painel esquerdo: senha e status ── -->
    <aside class="ticket-panel">
      <div class="ticket-panel__inner">

        <!-- bloco superior: senha, urgência, stats, chip -->
        <div class="ticket-top">
          <div>
            <div class="ticket-label">SUA SENHA</div>
            <div class="ticket-number">{{ entry?.ticket_number || "-" }}</div>
          </div>

          <div class="ticket-urgency">
            <div
              class="ticket-urgency__ring"
              :style="{ borderColor: store.urgencyColor, boxShadow: `0 0 0 8px ${store.urgencyColor}22` }"
            >
              <v-icon size="26" :color="store.urgencyColor">{{ urgencyIcon }}</v-icon>
            </div>
            <div class="ticket-urgency__text" :style="{ color: store.urgencyColor }">
              {{ session?.urgency_label || (session?.ai_summary ? "Classificando..." : "Aguardando") }}
            </div>
          </div>

          <div class="ticket-stats">
            <div class="ticket-stat">
              <div class="ticket-stat__label">POSIÇÃO</div>
              <div class="ticket-stat__value">
                {{ entry?.queue_position && entry?.status === "waiting" ? `${entry.queue_position}º` : "-" }}
              </div>
            </div>
            <div class="ticket-stat">
              <div class="ticket-stat__label">ESPERA</div>
              <div class="ticket-stat__value">{{ estimatedWait ? `~${estimatedWait} min` : "-" }}</div>
            </div>
          </div>

          <v-chip
            :color="statusChipColor"
            variant="tonal"
            size="small"
            class="ticket-chip"
          >
            <v-icon start size="12">{{ statusChipIcon }}</v-icon>
            {{ statusChipLabel }}
          </v-chip>
        </div>

        <!-- triagem indicou emergência e a pessoa ainda não está no local -->
        <div v-if="awaitingCheckin && session?.emergency" class="ticket-emergency">
          <v-icon color="#feb2b2" size="28">mdi-alert-octagon</v-icon>
          <div class="ticket-emergency__title">PROCURE ATENDIMENTO IMEDIATAMENTE</div>
          <div class="ticket-emergency__sub">
            Sua triagem indicou emergência. Venha agora ou, se não puder, ligue <strong>192 (SAMU)</strong>.
          </div>
        </div>

        <!-- check-in presencial: só entra na validação/fila ao chegar no local -->
        <div v-if="awaitingCheckin" class="ticket-checkin">
          <div class="ticket-checkin__title">Faça o check-in ao chegar</div>
          <div class="ticket-checkin__sub">Digite o código de 6 dígitos exibido na TV da recepção.</div>
          <input
            v-model="checkinCode"
            class="ticket-checkin__input"
            inputmode="numeric"
            autocomplete="one-time-code"
            maxlength="7"
            placeholder="000000"
            aria-label="Código de check-in"
            @keyup.enter="submitCheckin"
          />
          <v-btn
            block
            color="#38a169"
            class="text-white"
            :loading="checkingIn"
            :disabled="checkinDigits.length !== 6"
            @click="submitCheckin"
          >
            Fazer check-in
          </v-btn>
          <div v-if="checkinError" class="ticket-checkin__error">{{ checkinError }}</div>
          <div v-if="checkinDeadline" class="ticket-checkin__deadline">Prazo para o check-in: até {{ checkinDeadline }}</div>
          <div class="ticket-checkin__help">Sem celular ou com dificuldade? Fale com a recepção.</div>
        </div>

        <!-- notificação de chamada (âncora no rodapé do painel) -->
        <div v-if="entry?.status === 'called'" class="ticket-called">
          <v-icon color="#81e6b5" size="28">mdi-bell-ring</v-icon>
          <div class="ticket-called__title">DIRIJA-SE AO PONTO DE ATENDIMENTO</div>
          <div class="ticket-called__sub">A equipe está aguardando você.</div>
        </div>

      </div>
    </aside>

    <!-- ── Painel direito: fila geral ── -->
    <main class="board-panel">

      <div class="board-panel__header">
        <div>
          <div class="board-panel__title">Fila de Atendimento</div>
          <div class="board-panel__subtitle">Acompanhamento em tempo real</div>
        </div>
        <div class="board-panel__legend">
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

      <div class="board-panel__body">
        <div class="board-table-head">
          <div class="board-col board-col--pos">#</div>
          <div class="board-col board-col--ticket">SENHA</div>
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
          <div class="board-col board-col--pos">
            <span class="board-pos">{{ row.queue_position }}º</span>
          </div>
          <div class="board-col board-col--ticket">
            <span class="board-ticket" :class="{ 'board-ticket--mine': row.isMine }">
              {{ row.ticket_number }}
            </span>
          </div>
          <div class="board-col board-col--priority">
            <span class="urgency-dot" :style="{ background: urgencyColor(row.urgency_level) }"></span>
            <span :style="{ color: urgencyColor(row.urgency_level) }">{{ urgencyLabel(row.urgency_level) }}</span>
          </div>
          <div class="board-col board-col--name">
            {{ row.name }}
            <span
              v-if="row.priorityTier > 0"
              class="board-priority-badge"
              :class="{ 'board-priority-badge--super': row.priorityTier === 2 }"
              :title="row.priorityLabels.join(', ')"
            >★</span>
          </div>
          <div class="board-col board-col--wait">~{{ row.estimated_wait }} min</div>
        </div>
      </div>

    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useTriageStore } from "../../stores/triage"
import { useQueueChannel } from "../../composables/useCable"
import { apiFetch } from "../../composables/useApi"

const store = useTriageStore()
const route = useRoute()
const router = useRouter()

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

// Tempo estimado baseado na posição real do paciente na fila (15 min/pessoa).
// Atualizado automaticamente ao recarregar queueRows via ActionCable.
const estimatedWait = computed(() => {
  const mine = queueRows.value.find((r) => r.isMine)
  return mine ? mine.estimated_wait : null
})

const urgencyIcon = computed(() => {
  const level = entry.value?.urgency_level || session.value?.urgency_level
  const icons = {
    red: "mdi-alert-circle", orange: "mdi-alert", yellow: "mdi-clock-alert",
    green: "mdi-check-circle", blue: "mdi-information",
  }
  return icons[level] || "mdi-help-circle-outline"
})

// ── Check-in presencial ──
const awaitingCheckin = computed(() => session.value?.status === "awaiting_checkin")
const checkinCode = ref("")
const checkingIn = ref(false)
const checkinError = ref("")
const checkinDigits = computed(() => checkinCode.value.replace(/\D/g, ""))
const checkinDeadline = computed(() => {
  const deadline = session.value?.checkin_deadline
  if (!deadline) return null
  return new Date(deadline).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })
})

async function submitCheckin() {
  if (checkingIn.value || checkinDigits.value.length !== 6) return
  checkingIn.value = true
  checkinError.value = ""
  try {
    await store.checkIn(checkinDigits.value)
    checkinCode.value = ""
    await loadQueue()
  } catch (error) {
    checkinError.value = error.message
  } finally {
    checkingIn.value = false
  }
}

const statusChipColor = computed(() => {
  const s = session.value?.status
  if (s === "awaiting_checkin") return "orange"
  if (s === "awaiting_validation") return "warning"
  if (s === "in_queue") return "#90CDF4"
  if (s === "in_attendance" || entry.value?.status === "called") return "success"
  return "default"
})

const statusChipIcon = computed(() => {
  const s = session.value?.status
  if (s === "awaiting_checkin") return "mdi-map-marker-check-outline"
  if (s === "awaiting_validation") return "mdi-clock-outline"
  if (s === "in_queue") return "mdi-format-list-numbered"
  if (s === "in_attendance" || entry.value?.status === "called") return "mdi-bell"
  return "mdi-dots-horizontal"
})

const statusChipLabel = computed(() => {
  const s = session.value?.status
  if (s === "awaiting_checkin") return "Aguardando check-in no local"
  if (s === "awaiting_validation") return "Aguardando validação da equipe"
  if (s === "in_queue") return "Na fila de espera"
  if (entry.value?.status === "called") return "● CHAMANDO AGORA"
  if (s === "in_attendance") return "Em atendimento"
  return "..."
})

const queueRows = ref([])

async function loadQueue() {
  try {
    const data = await apiFetch("/api/queue")
    queueRows.value = (data.entries || []).map((e) => ({
      id:             e.id,
      urgency_level:  e.urgency_level,
      name:           e.name,
      priorityTier:   e.priority_tier,
      priorityLabels: e.priority_labels || [],
      estimated_wait: e.estimated_wait,
      queue_position: e.queue_position,
      ticket_number:  e.ticket_number,
      isMine:         e.is_mine,
    }))
  } catch {
    // silencioso
  }
}

onMounted(async () => {
  await store.fetchStatus()
  await loadQueue()
  if (session.value?.id) {
    unsubscribe = useQueueChannel(session.value.id, { onQueueUpdate: loadQueue })
  }

  // Veio pelo QR code da TV (/app/queue?checkin=123456): faz o check-in direto
  const qrCode = route.query.checkin
  if (qrCode) {
    router.replace({ query: {} })
    if (awaitingCheckin.value) {
      checkinCode.value = String(qrCode)
      await submitCheckin()
    }
  }
})

onUnmounted(() => unsubscribe?.())
</script>

<style scoped>
/* ── Layout principal ── */
.queue-layout {
  display: flex;
  height: calc(100vh - var(--v-layout-top, 56px));
  overflow: hidden;
  position: relative;
}

/* ── Painel esquerdo (senha/status) ── */
.ticket-panel {
  width: 320px;
  flex-shrink: 0;
  background: linear-gradient(170deg, #0d1b35 0%, #10213e 40%, #18345f 100%);
  border-right: 1px solid rgba(255, 255, 255, 0.08);
  overflow-y: auto; /* rola só se o card de check-in não couber */
  display: flex;
  flex-direction: column;
}

.ticket-panel__inner {
  padding: 1.2rem 1.2rem;
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  color: #fff;
  min-height: 0;
  text-align: center;
}

/* ── Bloco superior: senha + urgência + stats + chip ── */
.ticket-top {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.65rem;
  width: 100%;
}

.ticket-label {
  font-size: 0.65rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: #90b8d8;
}

.ticket-number {
  font-size: 1.9rem;
  font-weight: 900;
  letter-spacing: 0.1em;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  line-height: 1.1;
}

.ticket-urgency {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.4rem;
}

.ticket-urgency__ring {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  border: 3px solid;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.06);
  flex-shrink: 0;
}

.ticket-urgency__text {
  font-size: 0.95rem;
  font-weight: 700;
  text-align: center;
}

.ticket-stats {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;
  width: 100%;
}

.ticket-stat {
  padding: 0.5rem 0.6rem;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.07);
  border: 1px solid rgba(255, 255, 255, 0.13);
  text-align: left;
}

.ticket-stat__label {
  font-size: 0.6rem;
  text-transform: uppercase;
  letter-spacing: 0.09em;
  color: #90b8d8;
}

.ticket-stat__value {
  margin-top: 0.1rem;
  font-size: 1rem;
  font-weight: 800;
}

.ticket-chip {
  align-self: center;
}

/* ── Check-in presencial ── */
.ticket-checkin {
  border-radius: 12px;
  padding: 0.85rem 0.9rem;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(144, 205, 244, 0.35);
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.ticket-checkin__title {
  font-weight: 800;
  font-size: 0.95rem;
  color: #fff;
}

.ticket-checkin__sub,
.ticket-checkin__help,
.ticket-checkin__deadline {
  font-size: 0.75rem;
  color: #b8cde3;
  line-height: 1.35;
}

.ticket-checkin__input {
  width: 100%;
  padding: 0.55rem;
  border-radius: 10px;
  border: 1px solid rgba(255, 255, 255, 0.25);
  background: rgba(0, 0, 0, 0.25);
  color: #fff;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 1.6rem;
  font-weight: 800;
  letter-spacing: 0.3em;
  text-align: center;
  outline: none;
}

.ticket-checkin__input:focus {
  border-color: #63b3ed;
}

.ticket-checkin__error {
  font-size: 0.8rem;
  color: #feb2b2;
  font-weight: 600;
}

/* ── Emergência fora do local ── */
.ticket-emergency {
  border-radius: 12px;
  padding: 0.75rem 0.9rem;
  background: rgba(229, 62, 62, 0.18);
  border: 1px solid rgba(252, 129, 129, 0.7);
  text-align: center;
  width: 100%;
}

.ticket-emergency__title {
  margin-top: 0.3rem;
  font-weight: 800;
  color: #feb2b2;
  font-size: 0.85rem;
  line-height: 1.3;
}

.ticket-emergency__sub {
  margin-top: 0.2rem;
  color: #fed7d7;
  font-size: 0.75rem;
  line-height: 1.35;
}

/* ── Notificação de chamada ── */
.ticket-called {
  border-radius: 12px;
  padding: 0.75rem 0.9rem;
  background: rgba(56, 161, 105, 0.15);
  border: 1px solid rgba(56, 161, 105, 0.5);
  text-align: center;
  width: 100%;
  flex-shrink: 0;
}

.ticket-called__title {
  margin-top: 0.3rem;
  font-weight: 800;
  color: #81e6b5;
  font-size: 0.85rem;
  line-height: 1.3;
}

.ticket-called__sub {
  margin-top: 0.15rem;
  color: #c6f6d5;
  font-size: 0.75rem;
}

/* ── Painel direito (fila geral) ── */
.board-panel {
  flex: 1;
  background: #f4f8fd;
  overflow: hidden; /* sem scrollbar na página */
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.board-panel__header {
  display: flex;
  gap: 1rem;
  align-items: flex-start;
  justify-content: space-between;
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #dce8f5;
  background: linear-gradient(180deg, #ffffff 0%, #f0f6ff 100%);
  flex-shrink: 0;
  flex-wrap: wrap;
}

.board-panel__title {
  font-size: 1.1rem;
  font-weight: 800;
  color: #1f3658;
}

.board-panel__subtitle {
  margin-top: 0.1rem;
  font-size: 0.8rem;
  color: #6b7f99;
}

.board-panel__legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  justify-content: flex-end;
}

.board-panel__body {
  flex: 1;
  overflow-y: auto; /* scroll apenas dentro da tabela, não na página */
  min-height: 0;
}

.board-table-head,
.board-row {
  display: flex;
  padding: 0 1.5rem;
}

.board-table-head {
  padding-top: 0.55rem;
  padding-bottom: 0.55rem;
  border-bottom: 1px solid #dce8f5;
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.09em;
  text-transform: uppercase;
  color: #6b7f99;
  background: #f8fbff;
  position: sticky;
  top: 0;
  z-index: 1;
}

.board-row {
  padding-top: 0.9rem;
  padding-bottom: 0.9rem;
  align-items: center;
  border-bottom: 1px solid #e8eef7;
  color: #35506f;
  font-size: 0.93rem;
}

.board-row--mine {
  background: #bee3f8;
  box-shadow: inset 4px 0 0 #2b6cb0;
  color: #1a365d;
  font-weight: 700;
}

.board-col {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.board-col--pos      { flex: 0 0 42px; }
.board-col--ticket   { flex: 0 0 130px; }
.board-col--priority { flex: 1.2; font-weight: 700; }
.board-col--name     { flex: 2;   color: #2d4a6b; font-weight: 600; }
.board-col--wait     { flex: 1.2; color: #6b7f99; }

.board-priority-badge {
  margin-left: 0.35rem;
  color: #b7791f;
  font-size: 0.85rem;
}

.board-priority-badge--super {
  color: #c53030;
}

.board-pos {
  font-size: 0.8rem;
  font-weight: 700;
  color: #a0aec0;
}

.board-ticket {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.82rem;
  font-weight: 700;
  color: #4a5568;
  background: #edf2f7;
  border-radius: 5px;
  padding: 0.15rem 0.5rem;
  letter-spacing: 0.04em;
}

.board-ticket--mine {
  background: #ebf8ff;
  color: #2b6cb0;
  border: 1px solid #bee3f8;
}

.board-empty {
  padding: 3rem 1rem;
  text-align: center;
  color: #a0aec0;
  font-size: 0.95rem;
}

.urgency-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  display: inline-block;
  flex-shrink: 0;
}

/* ── Responsivo: tablet ── */
@media (max-width: 900px) {
  .queue-layout {
    flex-direction: column;
    height: auto;
    overflow: visible;
  }

  .ticket-panel {
    width: 100%;
    overflow: visible;
    border-right: none;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }

  .ticket-panel__inner {
    justify-content: flex-start;
    gap: 0.9rem;
  }

  .ticket-number { font-size: 1.8rem; }

  .board-panel {
    overflow: visible;
    min-height: 50vh;
  }

  .board-panel__body {
    overflow: visible;
  }

  .board-panel__header {
    flex-direction: column;
    gap: 0.6rem;
  }

  .board-panel__legend {
    justify-content: flex-start;
  }
}

/* ── Responsivo: mobile ── */
@media (max-width: 480px) {
  .board-table-head,
  .board-row {
    padding-left: 1rem;
    padding-right: 1rem;
    font-size: 0.82rem;
  }
}
</style>
